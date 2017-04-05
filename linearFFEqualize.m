function [output, w, costs] = linearFFEqualize(InputSignal, TrainingSignal, varargin)
	% This function performs the feed forward equalization with LMS or RLS algorithm.
	% First, the %InputSignal% and %TrainingSignal% will be normalized to 0-1.
	% The training will use all the %InputSignal% and will be performed %epoch% times.
	% The %alpha% is the learning rate of LMS or the forgetting factor of RLS, 
	% which should be chosen carefully with the help of curve of convergence. 
	% After training, the equalization will be performed and then the result will 
	% be returned.
	%
	% input: 
	%     InputSignal
	%       The input signal to be equalized.
	%     TrainingSignal
	%       The actual signal to be equalized to.
	%     AlgType (optional)
	%       'lms' for LMS or 'rls' for RLS.
	%       Default: 'lms'
	%     FFETaps (optional)
	%       The numbers of FFE taps which must be odd.
	%       Default: 5
	%     alpha (optional)
	%       The learning rate of LMS algorithm or the forgetting factor of RLS.
	%       Default: 0.01 for AlgType = 'lms', 0.99 for AlgType = 'rls'
	%     epoch (optional)
	%       The epoch of the learning of LMS through all the input signal.
	%       Default: 1
	% output:
	%     output
	%       The equalized signal with the same length of InputSignal
	%       Size: length(InputSignal), 1
	%     w
	%       Weights of FFE
	%       Size: FFETaps, 1
	%     costs
	%       The costs after each training epoch, which is used to draw a 
	%       curve of convergence and thus determine the best learning rate.
	
	%% Parameter Checking
	narginchk(2, 6);
	
	if nargin == 2
		AlgType = 'lms';
	else
		AlgType = varargin{1};
	end
	if nargin <= 3
		FFETaps = 5;
	else
		FFETaps = varargin{2};
	end
	if nargin <= 4
		if AlgType == 'lms'
			alpha = 0.01;
		elseif AlgType == 'rls'
			alpha = 0.99;
		else
			error('linearFeedForwardEqualize:argChk', 'AlgType must be lms or rls');
		end
	else
		alpha = varargin{3};
	end
	if nargin <= 5
		epoch = 1;
	else
		epoch = varargin{4};
	end
	
	% FFETaps must equals to a odd number
	if mod(FFETaps, 2) == 0
		error('lmsFeedForwardEqualize:argChk', 'FFE taps must be odd');
	end
	
	%% Signal Normalization and Duplication
	% InputSignal and TrainingSignal is normalized to the range between 0-1.
	InputSignal = InputSignal - min(InputSignal);
	InputSignal = InputSignal / max(InputSignal);
	TrainingSignal = TrainingSignal - min(TrainingSignal);
	TrainingSignal = TrainingSignal / max(TrainingSignal);
	
	% Both signal is duplicated for better performance
	InputSignalDup = repmat(InputSignal, 2, 1);
	TrainingSignalDup = repmat(TrainingSignal, 2, 1);
	% Zero Padding for input signal
	InputSignalZP = [zeros(floor(FFETaps/2), 1); InputSignalDup; zeros(floor(FFETaps/2), 1)];
	
	%% Weights Initializing
	w = zeros(FFETaps, 1);
	w(floor(length(w)/2) + 1) = 1;
	
	%% Training
	costs = zeros(epoch, 1);
	if AlgType == 'lms'
		% The LMS learning algorithm
		for n = 1 : epoch
			for i = 1 : length(InputSignalZP) - FFETaps + 1
				y(i) = w' * InputSignalZP(i : i + FFETaps - 1);
				w = w - alpha * (y(i) - TrainingSignalDup(i)) * InputSignalZP(i : i + FFETaps - 1);
				costs(n) = costs(n) + 0.5 * ((y(i) - TrainingSignalDup(i)) ^ 2);
			end
			% Record the cost/error of each epoch
			costs(n) = costs(n) / (length(InputSignalZP) - FFETaps + 1);
		end
	elseif AlgType == 'rls'
		% The RLS learning algorithm
		Sd = eye(FFETaps);
		for n = 1 : epoch
			for i = 1 : length(InputSignalZP) - FFETaps + 1
				x = InputSignalZP(i : i + FFETaps - 1);
				e = TrainingSignalDup(i) - w' * x;
				phi = Sd * x;
				Sd = (1 / alpha) * (Sd - (phi * phi') / (alpha + phi' * x));
				w = w + e * Sd * x;
				costs(n) = costs(n) + 0.5 * (e ^ 2);
			end
			% Record the cost/error of each epoch
			costs(n) = costs(n) / (length(InputSignalZP) - FFETaps + 1);
		end
	end
	
	%% Using Trained Weights to Equalize Data
	for i = 1 : length(InputSignalZP) - FFETaps + 1
		y(i) = w' * InputSignalZP(i : i + FFETaps - 1);
	end
	
	y = y';
	
	% TODO choose a half of the output
	output = y(1 : length(y) / 2);
	% output = y(length(y) / 2 + 1 : end);
