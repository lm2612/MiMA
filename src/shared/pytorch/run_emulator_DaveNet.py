'''
This python script outlines contains all python commands MiMA will use.
It needs in the same dir: arch_DaveNet.py and network_wst.pkl.
'''
from torch import load, device, no_grad, reshape, transpose, zeros, tensor, float64

# Initialize everything
def initialize(path_weights_stats='network_wst.pkl'):
    """
    Initialize a WaveNet model and load weights.

    Parameters
    __________
    path_weights_stats : pickled object that contains weights and statistics (means and stds).

    """
    import arch_DaveNet as m;
    device_str = "cpu"
    checkpoint = load(path_weights_stats, map_location=device(device_str))
    model=m.WaveNet(checkpoint).to(device_str);

    # Load weights and set to evaluation mode.
    model.load_state_dict(checkpoint['weights'])
    model.eval()
    del checkpoint
    return model

# Compute drag
def compute_reshape_drag(*args):
    """
    Take in input arguments passed from MiMA and output drag in shape desired by MiMA.
    Reshaping & porting to torch.tensor type, and applying model.forward is performed.

    Parameters
    __________
    model : WaveNet model ready to be deployed.
    wind : U or V                      :: (128, num_col, 40)
    lat : latitudes                    :: (num_col)
    ps : surface pressure              :: (128, num_col)
    Y_out : output prellocated in MiMA :: (128, num_col, 40)
    num_col : # of latitudes on this proc 

    """
    model, wind, lat, ps, Y_out, num_col= args
    imax=128

    # Reshape and put all input variables together [wind, lat, ps]
    X = zeros((imax*num_col,42), dtype=float64)
    X[:,:40] = reshape(tensor(wind),(imax*num_col,40)) # wind[i,j,:] is now at X[i*num_col+j,:40]
    for i in range(num_col):
        X[i::num_col,40]=lat[i]                        # lat[j] is at X[j::num_col,40].
    X[:,41] = reshape(tensor(ps),(imax*num_col,))      # ps[i,j] is now at X[i*num_col+j,41].
    
    # Apply model.
    with no_grad():
        temp = model(X)

    # Reshape into what MiMA needs.    
    Y_out[:,:,:]=reshape(temp,(imax,num_col,40))       # Y_out[i,j,:] was temp[i*num_col+j,:].
    del temp
    return Y_out



