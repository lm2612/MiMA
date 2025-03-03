  !-----------------------------------------------------------------
  !    This module is a dummy version of the ML coupling, provided
  !    to allow compilation when not using any ML component.
  !    It does nothing in each routine, and should not get called.
  !-----------------------------------------------------------------

module cg_drag_ML_mod

    implicit none

    public cg_drag_ML_init, &
        cg_drag_ML, &
        cg_drag_ML_end

    contains

    subroutine cg_drag_ML_init(model_dir, model_name_zonal, model_name_meridional)
        ! Parameters
        character(len=1024), intent(in)        :: model_dir, model_name_zonal, model_name_meridional
        ! Nothing to do for null
    end subroutine cg_drag_ML_init

    subroutine cg_drag_ML(uuu, vvv, temp, psfc, lat, gwfcng_x, gwfcng_y)
        real, dimension(:,:,:), intent(in)    :: uuu, vvv, temp
        real, dimension(:,:),   intent(in)    :: lat, psfc

        real, dimension(:,:,:), intent(out), target   :: gwfcng_x, gwfcng_y
        ! Nothing to do for null
    end subroutine cg_drag_ML

    subroutine cg_drag_ML_end()
        ! Nothing to do for null
    end subroutine cg_drag_ML_end

end module cg_drag_ML_mod
