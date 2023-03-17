import run_emulator_DaveNet as RED

import numpy as np
imax=128; num_col=4
wind = np.random.randn(imax,num_col,40);
lat = np.random.randn(num_col)
ps = np.random.randn(imax,num_col)
Y_out = np.zeros((imax,num_col,40))

model = RED.initialize()
Y_out = RED.compute_reshape_drag(model,wind,lat,ps,Y_out,num_col)



