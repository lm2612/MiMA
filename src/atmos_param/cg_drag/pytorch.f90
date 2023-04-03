module pytorch_mod

! #ML
! Imports primitives used to interface with C
use, intrinsic :: iso_c_binding, only: c_int64_t, c_float, c_char, c_null_char, c_ptr, c_loc
! Import library for interfacing with PyTorch
use ftorch

!-------------------------------------------------------------------

implicit none
private

public    cg_drag 


namelist / cg_drag_nml /         &
                          cg_drag_freq, cg_drag_offset, &
                          source_level_pressure, damp_level_pressure

contains

subroutine cg_drag(uuu, vvv, psfc, lat, gwfcng_x, gwfcng_y)

  !-----------------------------------------------------------------
  !    cg_drag returns the x and y gravity wave drag forcing terms
  !    following calculation using an external neural net.
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
  
  real, dimension(:,:,:), intent(in)    :: uuu, vvv
  real, dimension(:,:),   intent(in)    :: lat, psfc
  
  real, dimension(:,:,:), intent(out)   :: gwfcng_x, gwfcng_y

  character(len=128), intent(in)        :: model_path
  
  !-----------------------------------------------------------------

  !-------------------------------------------------------------------
  !    local variables:
  !
  !       dtdz          temperature lapse rate [ deg K/m ]
  !
  !---------------------------------------------------------------------

  real, dimension(:,:), intent(in)    :: uuu_reshaped, vvv_reshaped
  real, dimension(:),   intent(in)    :: lat_reshaped, psfc_reshaped

  integer(c_int), parameter :: dims_2D = 2
  integer(c_int64_t) :: shape_2D(dims_2D) = (/ 10, 10 /)
  integer(c_int), parameter :: dims_1D = 1
  integer(c_int64_t) :: shape_1D(dims_1D) = (/ 10 /)

  ! Set up types of input and output data and the interface with C
  type(torch_module) :: model
  type(torch_tensor) :: uuu_tensor, vvv_tensor, lat_tensor, psfc_tensor,&
                        gwfcng_x_tensor, gwfcng_y_tensor
  
  !----------------------------------------------------------------

  ! reshape tensors as required
  ! wind becomes (128 * Ncol * 40)

  u_flat = magic_flattening_code(uuu)
  uuu_reshaped = transpose(u_flat)

  ! Create input/output tensors from the above arrays
  uuu_tensor = torch_tensor_from_blob(c_loc(uuu_reshaped), dims_2D, shape_2D, torch_kFloat32, torch_kCPU)
  vvv_tensor = torch_tensor_from_blob(c_loc(vvv_reshaped), dims_2D, shape_2D, torch_kFloat32, torch_kCPU)

  out_tensor = torch_tensor_from_blob(c_loc(out_data), out_dims, out_shape, torch_kFloat32, torch_kCPU)

  ! Load model and Infer
  model = torch_module_load(c_char_model_path//c_null_char)
  call torch_module_forward(model, uuu_tensor, gwfcng_x_tensor)
  call torch_module_forward(model, vvv_tensor, gwfcng_y_tensor)


  ! Convert back into fortran types, reshape, and assign to gwfcng


  ! Cleanup
  call torch_module_delete(model)
  call torch_tensor_delete(in_tensor)
  call torch_tensor_delete(out_tensor)
  ! deallocate(in_data)
  ! deallocate(out_data)


end subroutine cg_drag
