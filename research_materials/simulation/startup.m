% Add cleanroom code directories when MATLAB starts in this folder.
P = project_paths();
addpath(P.root, P.run, P.export, P.plot, P.src);
addpath(genpath(P.src));
