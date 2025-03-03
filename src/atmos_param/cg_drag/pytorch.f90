module cg_drag_ML_mod

use constants_mod, only:  RADIAN
use fms_mod,       only:   mpp_pe

! #ML
! Import library for interfacing with PyTorch
use ftorch

!-------------------------------------------------------------------

implicit none
private

public    cg_drag_ML_init, cg_drag_ML_end, cg_drag_ML

!--------------------------------------------------------------------
!   data used in this module to bind to FTorch
!
!--------------------------------------------------------------------
!   model    ML model type bound to python
!
!--------------------------------------------------------------------

type(torch_model) :: model_zonal, model_meridional


!--------------------------------------------------------------------
!--------------------------------------------------------------------

contains

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
!                      PUBLIC SUBROUTINES
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


!####################################################################

subroutine cg_drag_ML_init(model_dir, model_name_zonal, model_name_meridional)

  !-----------------------------------------------------------------
  !    cg_drag_ML_init is called from cg_drag_init and initialises
  !    anything required for the ML calculation of cg_drag such as
  !    an ML model
  !
  !-----------------------------------------------------------------
  
  !-----------------------------------------------------------------
  !    intent(in) variables:
  !
  !       model_dir    full filepath to the model directory
  !       model_name_zonal      filename of the TorchScript model in 
  !                               zonal direction
  !       model_name_meridional filename of the TorchScript model in 
  !                               meridional direction
  !
  !-----------------------------------------------------------------
  character(len=1024), intent(in)        :: model_dir
  character(len=1024), intent(in)        :: model_name_zonal, model_name_meridional

  !-----------------------------------------------------------------
  
  ! Initialise the ML model to be used
   call torch_model_load(model_zonal, trim(model_dir)//trim(model_name_zonal), torch_kCPU)
   call torch_model_load(model_meridional, trim(model_dir)//trim(model_name_meridional), torch_kCPU)
    
end subroutine cg_drag_ML_init


!####################################################################

subroutine cg_drag_ML_end

  !-----------------------------------------------------------------
  !    cg_drag_ML_end is called from cg_drag_end and is a destructor
  !    for anything used in the ML part of calculating cg_drag such
  !    as an ML model.
  !
  !-----------------------------------------------------------------
  
  ! destroy the model
  call torch_delete(model_zonal)
  call torch_delete(model_meridional)

end subroutine cg_drag_ML_end


!####################################################################

subroutine cg_drag_ML(uuu, vvv, temp, psfc, lat, gwfcng_x, gwfcng_y)

  !-----------------------------------------------------------------
  !    cg_drag_ML returns the x and y gravity wave drag forcing
  !    terms following calculation using an external neural net.
  !
  !-----------------------------------------------------------------
  
  !-----------------------------------------------------------------
  !    intent(in) variables:
  !
  !       is,js    starting subdomain i,j indices of data in 
  !                the physics_window being integrated
  !       uuu,vvv  arrays of model u and v wind
  !       psfc     array of model surface pressure
  !       lat      array of model latitudes at cell boundaries [radians]
  !
  !    intent(out) variables:
  !
  !       gwfcng_x time tendency for u eqn due to gravity-wave forcing
  !                [ m/s^2 ]
  !       gwfcng_y time tendency for v eqn due to gravity-wave forcing
  !                [ m/s^2 ]
  !
  !-----------------------------------------------------------------
  real, dimension(:,:,:), intent(in)    :: uuu, vvv, temp
  real, dimension(:,:),   intent(in)    :: lat, psfc
  
  real, dimension(:,:,:), intent(out), target   :: gwfcng_x, gwfcng_y
  
  !-----------------------------------------------------------------

  !-------------------------------------------------------------------
  !    local variables:
  !
  !       dtdz          temperature lapse rate [ deg K/m ]
  !
  !---------------------------------------------------------------------

  real, dimension(:,:), allocatable, target  :: uuu_reshaped, vvv_reshaped, temp_reshaped
  real, dimension(:,:), allocatable, target    :: lat_reshaped, psfc_reshaped
  real, dimension(:,:), allocatable, target  :: gwfcng_x_reshaped, gwfcng_y_reshaped
  integer, dimension(:,:),  allocatable, target :: lat_ind

  integer :: imax, jmax, kmax, j, k, start_lat_ind

  integer, dimension(2) :: shape_1D
  integer, dimension(2) :: shape_2D

  ! Set up types of input and output data and the interface with C
  integer, parameter :: n_inputs = 5
  type(torch_tensor), dimension(n_inputs), target :: model_input_arr
  integer, parameter :: n_outputs = 1
  type(torch_tensor), dimension(n_outputs):: gwfcng_x_tensor, gwfcng_y_tensor
  
  !----------------------------------------------------------------

  ! reshape tensors as required
  imax = size(uuu, 1)
  jmax = size(uuu, 2)
  kmax = size(uuu, 3)

  ! Get starting latitude index
  start_lat_ind = mpp_pe()*jmax          ! from 0 to 64

  ! Note that the '1D' tensor has 2 dimensions, one of which is size 1
  shape_2D = (/ imax*jmax, kmax /)
  shape_1D = (/ imax*jmax, 1 /)

  ! flatten data (nlat, nlon, n) --> (nlat*nlon, n)
  allocate( uuu_reshaped(kmax, imax*jmax) )
  allocate( vvv_reshaped(kmax, imax*jmax) )
  allocate( temp_reshaped(kmax, imax*kmax) )

  allocate( lat_reshaped(1, imax*jmax) )
  allocate( psfc_reshaped(1, imax*jmax) )
  allocate( lat_ind(1, imax*jmax) )
  allocate( gwfcng_x_reshaped(kmax, imax*jmax) )
  allocate( gwfcng_y_reshaped(kmax, imax*jmax) )

  do j=1,jmax
      do k=1, kmax
          uuu_reshaped(k, (j-1)*imax+1:j*imax) = uuu(:,j,k)
          vvv_reshaped(k, (j-1)*imax+1:j*imax) = vvv(:,j,k)
          temp_reshaped(k, (j-1)*imax+1:j*imax) = temp(:,j,k)
      end do
      lat_reshaped(1, (j-1)*imax+1:j*imax) = lat(:,j) !!!*RADIAN
      psfc_reshaped(1, (j-1)*imax+1:j*imax) = psfc(:,j)
      lat_ind(1, (j-1)*imax+1:j*imax) = start_lat_ind + j - 1    !! python indexing
  end do

  ! Create input/output tensors from the above arrays
  call torch_tensor_from_array(model_input_arr(5), lat_ind, shape_1D, torch_kInt32, torch_kCPU)
  call torch_tensor_from_array(model_input_arr(4), psfc_reshaped, shape_1D, torch_kFloat64, torch_kCPU)
  call torch_tensor_from_array(model_input_arr(3), lat_reshaped, shape_1D, torch_kFloat64, torch_kCPU)
  call torch_tensor_from_array(model_input_arr(2), temp_reshaped, shape_2D, torch_kFloat64, torch_kCPU)

  ! Zonal
  call torch_tensor_from_array(model_input_arr(1), uuu_reshaped, shape_2D, torch_kFloat64, torch_kCPU)
  call torch_tensor_from_array(gwfcng_x_tensor(1), gwfcng_x_reshaped, shape_2D, torch_kFloat64, torch_kCPU)
  ! Run model and Infer
  call torch_model_forward(model_zonal, model_input_arr, gwfcng_x_tensor)
  
  ! Meridional
  call torch_tensor_from_array(model_input_arr(1), vvv_reshaped, shape_2D, torch_kFloat64, torch_kCPU)
  call torch_tensor_from_array(gwfcng_y_tensor(1), gwfcng_y_reshaped, shape_2D, torch_kFloat64, torch_kCPU)
  ! Run model and Infer
  call torch_model_forward(model_meridional, model_input_arr, gwfcng_y_tensor)


  ! Convert back into fortran types, reshape, and assign to gwfcng
  do j=1,jmax
      do k=1, kmax
          gwfcng_x(:,j,k) = gwfcng_x_reshaped(k, (j-1)*imax+1:j*imax)
          gwfcng_y(:,j,k) = gwfcng_y_reshaped(k, (j-1)*imax+1:j*imax)
      end do
  end do

  ! Cleanup
  call torch_delete(model_input_arr)
  call torch_delete(gwfcng_x_tensor)
  call torch_delete(gwfcng_y_tensor)
  deallocate( uuu_reshaped )
  deallocate( vvv_reshaped )
  deallocate( lat_reshaped )
  deallocate( psfc_reshaped )
  deallocate( gwfcng_x_reshaped )
  deallocate( gwfcng_y_reshaped )


end subroutine cg_drag_ML


!####################################################################

end module cg_drag_ML_mod
