function [ T1temp,MP2RAGEcorrected] = T1B1correctpackageTFL( B1img,MP2RAGEimg,T1,MP2RAGE,brain,varargin)
% usage
%
% [  T1corr MP2RAGEcorr] = T1B1correctpackage(B1,MP2RAGEimg,T1,MP2RAGE,brain,varargin)
%
% B1 and MP2RAGEimg (and T1) are the nii structures resulting from loading
% the MP2RAGE (MP2RAGEimg, T1) and the result of some B1 mapping technique
%  with load_nii or load_untouch_nii
%
% the variable B1 is compulsory
%
% Only MP2RAGEimg or the T1 have to be loaded (I usually use the MP2RAGEimg)
%
% the variables that are not loaded can be simply left empty []
%
% MP2RAGE  variable contains all the relevant sequence
% information as delailed below
%
% B1 will be given in relative units => 1 if it was correct; values can varie
% from 0-2
%
%     MP2RAGE.B0=7;           % in Tesla
%     MP2RAGE.TR=6;           % MP2RAGE TR in seconds
%     MP2RAGE.TRFLASH=6.7e-3; % TR of the GRE readout
%     MP2RAGE.TIs=[800e-3 2700e-3];% inversion times - time between middle of refocusing pulse and excitatoin of the k-space center encoding
%     MP2RAGE.NZslices=[40 80];% Slices Per Slab * [PartialFourierInSlice-0.5  0.5]
%     MP2RAGE.FlipDegrees=[4 5];% Flip angle of the two readouts in degrees
%
% brain can be an image in the same space as the MP2RAGE and the
% Sa2RAGE that has zeros where there is no need to do any T1/B1 calculation
% (can be a binary mask or not). if left empty the calculation is done
% everywhere
%
% additionally the inversion efficiency of the adiabatic inversion can be
% set as a last optional variable. Ideally it should be 1.
% In the first implementation of the MP2RAGE the inversino efficiency was
% measured to be ~0.96
%
% outputs are:
%  T1corr - T1map corrected for B1 bias
%  MP2RAGEcorr - MP2RAGE image corrected for B1 bias
%
%
% please cite:
% Marques, J.P., Gruetter, R., 2013. New Developments and Applications of the MP2RAGE Sequence - Focusing the Contrast and High Spatial Resolution R1 Mapping. PLoS ONE 8. doi:10.1371/journal.pone.0069294
% Marques, J.P., Kober, T., Krueger, G., van der Zwaag, W., Van de Moortele, P.-F., Gruetter, R., 2010a. MP2RAGE, a self bias-field corrected sequence for improved segmentation and T1-mapping at high field. NeuroImage 49, 1271–1281. doi:10.1016/j.neuroimage.2009.10.002
%


if nargin==6
    
    invEFF=varargin{1}
    
else
    
    invEFF=0.96;
    
end

if isempty(brain)
    
    if isempty(MP2RAGEimg)
        
        brain=T1;
        
        brain.img=ones(size(brain.img));
        
    else
        
        brain=MP2RAGEimg;
        
        brain.img=ones(size(brain.img));
        
    end
    
end

%% sanity check to see how B1 sensitive your sequence was

gcf=figure(3);

set(gcf,'Color',[1 1 1]);

hold off

for B1val=0.6:0.2:1.4
    
    [MP2RAGEamp,T1vector,IntensityBeforeComb]=MP2RAGE_lookuptable(2,MP2RAGE.TR,MP2RAGE.TIs,B1val*MP2RAGE.FlipDegrees,MP2RAGE.NZslices,MP2RAGE.TRFLASH,'normal');
    
    plot(MP2RAGEamp,T1vector,'color',[0.5 0.5 0.5]*B1val,'Linewidth',2)
    
    hold on
    
end

legend('B1=0.6','B1=0.8','B1=1','B1=1.2','B1=1.4')

% examples of T1 values at 3T

if ~isfield(MP2RAGE,'B0')
    
    T1WM=1.1;
    
    T1GM=1.85;
    
    T1CSF=3.5;
    
else
    
    if MP2RAGE.B0==3
        
        T1WM=0.85;
        
        T1GM=1.35;
        
        T1CSF=2.8;
        
    else
        
        % examples of T1 values at 7T
        
        T1WM=1.1;
        
        T1GM=1.85;
        
        T1CSF=3.5;
        
    end
    
end

plot([-0.5 0.5],[T1CSF T1CSF;T1GM T1GM;T1WM T1WM]','Linewidth',2)

text(0.35,T1WM,'White Matter')

text(0.35,T1GM,'Grey Matter')

text(0.35,T1CSF,'CSF')

ylabel('T1');

xlabel('MP2RAGE');

%% definition of range of B1s and T1s and creation of MP2RAGE and Sa2RAGE lookupvector to make sure the input data for the rest of the code is the Sa2RAGEimg and the MP2RAGEimg

B1_vector=0.005:0.05:1.9;

T1_vector=0.5:0.05:5.2;

[MP2RAGE.Intensity MP2RAGE.T1vector ]=MP2RAGE_lookuptable(2,MP2RAGE.TR,MP2RAGE.TIs,MP2RAGE.FlipDegrees,MP2RAGE.NZslices,MP2RAGE.TRFLASH,'normal',invEFF)

if isempty(MP2RAGEimg)
    
    T1.img=double(T1.img)/1000;
    
    MP2RAGEimg.img=reshape(interp1(MP2RAGE.T1vector,MP2RAGE.Intensity,T1.img(:)),size(B1img.img));
    
    MP2RAGEimg.img(isnan(MP2RAGEimg.img))=-0.5
    
else
    
    MP2RAGEimg.img=double(MP2RAGEimg.img)/4095-0.5;
    
end


%% now the fun starts

% creates a lookup table of MP2RAGE intensities as a function of B1 and T1

k=0;

for b1val=B1_vector
    
    k=k+1;
    
    [Intensity T1vector ]=MP2RAGE_lookuptable(2,MP2RAGE.TR,MP2RAGE.TIs,b1val*MP2RAGE.FlipDegrees,MP2RAGE.NZslices,MP2RAGE.TRFLASH,'normal',invEFF);
    
    MP2RAGEmatrix(k,:)=interp1(T1vector,Intensity,T1_vector);
    
end

k=0;



%% make the matrix  MP2RAGEMatrix into T1_matrix(B1,ratio)

npoints=40;

MP2RAGE_vector=linspace(-0.5,0.5,npoints);

k=0;

for b1val=B1_vector
    
    k=k+1;
    
    try
        
        T1matrix(k,:)=interp1(MP2RAGEmatrix(k,:),T1_vector,MP2RAGE_vector,'pchirp');
        
    catch
        
        temp=MP2RAGEmatrix(k,:);
        
        temp(isnan(temp))=linspace(-0.5-eps,-1,length(find(isnan(temp)==1)));
        
        temp=interp1(temp,T1_vector,MP2RAGE_vector);
        
        T1matrix(k,:)=temp;
        
        
        
    end
    
end

%% correcting the estimates of T1 and B1 iteratively

T1temp=MP2RAGEimg;

brain.img(B1img.img==0)=0;

brain.img(MP2RAGEimg.img==0)=0;

T1temp.img(brain.img==0)=0;

T1temp.img(brain.img==1)=0;

B1img.img(brain.img==0)=0;




temp=squeeze(T1temp.img(:,end/2,:));



T1temp.img(brain.img~=0)=interp2(MP2RAGE_vector,B1_vector,T1matrix,MP2RAGEimg.img(brain.img~=0),B1img.img(brain.img~=0))

T1temp.img(isnan(T1temp.img))=4;



temp2=squeeze(T1temp.img(:,end/2,:));



gcf=figure(1);

set(gcf,'Color',[1 1 1]);

imagesc(temp2-temp);colorbar

title(['T1 correction ']);

colormap(gray)


%% creates an MP2RAGEcorrected image and puts both the B1 and T1 in the ms scale

[MP2RAGE.Intensity MP2RAGE.T1vector ]=MP2RAGE_lookuptable(2,MP2RAGE.TR,MP2RAGE.TIs,MP2RAGE.FlipDegrees,MP2RAGE.NZslices,MP2RAGE.TRFLASH,'normal',invEFF)

MP2RAGEcorrected=MP2RAGEimg;

MP2RAGEcorrected.img=reshape(interp1(MP2RAGE.T1vector,MP2RAGE.Intensity,T1temp.img(:)),size(T1temp.img));

MP2RAGEcorrected.img(isnan(MP2RAGEcorrected.img))=-0.5;

MP2RAGEcorrected.img=round(4095*(MP2RAGEcorrected.img+0.5));

T1temp.img=(T1temp.img)*1000;


%%

showimages=0

if showimages==1;
    
    imagesc(MP2RAGE_vector,B1_vector,T1matrix,[0.4 5]);colorbar;
    
    xlabel ('MP2RAGE','FontSize',12,'FontWeight','bold')
    
    ylabel ('B_1','FontSize',12,'FontWeight','bold')
    
    title('T_1 look-up table','FontSize',12,'FontWeight','bold')
    
    H=gca
    
    set(H,'FontSize',12,'LineWidth',2)
    
    axes(H)
    
    
    
end

end

