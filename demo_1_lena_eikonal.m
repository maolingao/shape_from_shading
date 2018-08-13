clear
close all

do_export_obj = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get dedicated Matlab function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

addpath(genpath('Toolbox/'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set the problem
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Load Lena image, and scale to [0,1]
pkg load image;
data.I = imresize(rgb2gray(imread('Data/lena.png')),0.5);
data.I = double(data.I)./255;

% Set frontal, gray lighting
data.s(1,:) = [0 0 -1 0 0 0 0 0 0]; % SH2 lighting in red channel
%%%data.s(2,:) = [0 0 -1 0 0 0 0 0 0]; % SH2 lighting in green channel
%%%data.s(3,:) = [0 0 -1 0 0 0 0 0 0]; % SH2 lighting in blue channel

% Set uniform white albedo
data.rho = ones(size(data.I));

% Set orthographic camera
data.K = zeros(3,3); % Intrinsics

% Set reconstruction domain
data.mask = ones(size(data.I(:,:,1))); % SFS mask

% Set shape prior
data.z0 = zeros(size(data.I(:,:,1))); % Flat depth map at z = 0
data.mask_z0 = ones(size(data.I(:,:,1))); % Pixels where the prior is used
data.z_init = peaks(size(data.I(:,:,1),1)); % Initialization


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Show the inputs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

figure()
subplot(1,3,1)
imshow(uint8(255*data.I))
title('Input RGB image')

subplot(1,3,2)
XYZ = NaN*ones(size(data.I,1)*size(data.I,2),3);
[xx,yy] = meshgrid(1:size(data.I,2),1:size(data.I,1));
imask = find(data.mask>0);
xx = xx(imask);
yy = yy(imask);
if(data.K(1,3)>0)
	xx = (xx-data.K(1,3))./data.K(1,1);
	yy = (yy-data.K(2,3))./data.K(2,2);
	XYZ(imask,1) = data.z0(imask).*xx;
	XYZ(imask,2) = data.z0(imask).*yy;
	XYZ(imask,3) = data.z0(imask);
else
	XYZ(imask,1) = xx;
	XYZ(imask,2) = yy;
	XYZ(imask,3) = data.z0(imask);
end
XYZ = reshape(XYZ,[size(data.I,1) size(data.I,2) 3]);
surfl(XYZ(:,:,1),XYZ(:,:,2),-XYZ(:,:,3),[0 90])
shading flat
colormap gray
axis ij
axis tight
axis equal
view(-30,40)
title('Input Shape prior')

subplot(1,3,3)
SH_rendering = uint8(255*render_SH(data.s,256));
imshow(SH_rendering); 
title('Frontal lighting')

drawnow

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set the model parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

params.lambda = 1; % 0: no SfS / >0: weight of the SfS
params.mu = 0.0001; % 0: no shape prior / >0: weight of the shape Prior 
params.nu = 0.25; % 0: no spatial regularization / >0: weight of the smoothing

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set the algorithm parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
options.precond_pcg = 'ichol'; % Preconditioner for the inner PCG iterations (can be 'none', 'ichol' or 'cmg')
options.ratio = 1; % Ratio = n subsamples everything by a factor of n (useful for debug)
options.display = 1; % Set to 1 to plot the result at each iteration, 0 otherwise

options.maxit = 100; % Stopping criterion (max number of iterations)
options.minit = 5; % Min number of iterations (because first iterations might be weird)
options.tolFun = 1e-9; % Stopping criterion (relative difference on energy)
options.tolX = 0.001*options.tolFun; % Stopping criterion (relative difference on depth)
options.tolEps = 1e-3; % Stopping criterion (primal dual gap)
options.beta = 1e0; % Initial stepsize on theta for ADMM iterations
options.tau = 10.0; % Update beta if primal/dual > tau
% why if primal/dual > tau, then ultiply beta by eta ?
options.eta = 2.0; % Multiply beta by eta if primal/dual > tau
options.use_jac = 0; % 0: user-defined differentiation, 1: numerical
options.check_grad = 'off'; % Set to 'on' to check jacobian (debug only)
options.maxit_bfgs = 100; % Stopping criterion for the inner BFGS iterations
options.tolX_bfgs = 1e-9; % Stopping criterion for the inner BFGS iterations
options.tolFun_bfgs = 1e-10; % Stopping criterion for the inner BFGS iterations
options.maxit_pcg = 100; % Stopping criterion for the inner PCG iterations
options.tolFun_pcg = 1e-10; % Stopping criterion for the inner PCG iterations

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Call the routine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[z,N,XYZ,N_SH] = generic_sfs(data,params,options);


figure()
surfl(XYZ(:,:,1),XYZ(:,:,2),-XYZ(:,:,3),[0 90])
shading flat
colormap gray
axis ij
axis tight
axis equal
view(-30,40)
title('Shape from shading result with prior and regularization')
drawnow

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Export results
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if(do_export_obj)
	rho = 0.8*data.rho./max(data.rho(:));
	if(size(rho,3) == 1)
		rho = repmat(rho,[1 1 3]);
	end
	export_obj2(XYZ,N,rho,data.mask,'result_lena_prior_smooth');
end
