function [MS]=calc_turbulence_epsifish_Tdiff(Profile,tscan,f,fmax,Meta_Data)

%  MS structure for Micro Structure. Inside MS you ll find
%  temperature spectra in degC Hz^-1
%  Horizontal  velocity spectra in m^2/s^-2 Hz^-1
%  Acceleration/speed spectra in s^-1 Hz^-1 
%
%  input: 
% .     Meta_Data
% . created with Meta_Data=create_Meta_Data(file). Meta_Data contain the
% . path to calibration file and EPSI configuration needed to process the
% . epsi data
% .     Profile
% . EPSI data splitted in cast + T,S,P from the ctd (from EPSI_create_profile)
% .     tscan
% . length in second of the scan (piece of the profile)
% .     f
% . frequency array on wich you will 
% .     fmax
%  
%  output:
% . MS=
%  indscan: {1�237 cell} :  indexes of 3s scan from profile 
%        nbscan: 237 => number of scans
%          fmax: 45 => hard cut off frequency
%     nbchannel: 7 => number of channels
%             w: [1�237 double] => vertical speed per scan
%             t: [1�237 double] => temperature per scan
%             s: [1�237 double] => salinity per scan
%            pr: [1�237 double] => pressure per scan
%          kvis: [237�1 double] => kinematic viscosity per scan
%         ktemp: [237�1 double] => diffusivity per scan
%             f: [1�485 double] => frequency array
%             k: [1�1201 double] => Vertical wavenumber array
%            Pf: [7�237�485 double]: Frequency spectra per scan and channels 
%          kmax: [1�237 double]=> dynamic cut off frequency per scan
%       PphiT_k: [237�1201�2 double] => T? gradiant wavenumber spectra 
%      Pshear_k: [237�1201�2 double] => shear wavenumber spectra
%      Paccel_k: [237�1201�3 double]=>acceleration wavenumber spectra
%       epsilon: [237�2 double]: epsilon profiles
%            kc: [237�2 double]=>
%          Ppan: [237�1201�2 double]=> Panchev spectra
%      fc_index: [237�2 double]=> dynmic cut off for T? spectra
%           chi: [237�2 double]=>chi profile
% 



%
%  Created by Arnaud Le Boyer on 7/28/18.

%% get channels
channels=Meta_Data.PROCESS.channels;
nb_channels=length(channels);
%% Gravity  ... of the situation :)
G       = 9.81;

%% Length of the Profile
T       = length(Profile.epsitime);
df      = f(1);
%% define number of scan in the profile
Lscan   = tscan*2*f(end);
nbscan  = floor(T/Lscan);

%% we compute spectra on scan with 50% overlap
nbscan=2*nbscan-1;

%% define the fall rate of the Profile. 
%  Add Profile.w with w the vertical vel. 
%  We are using the pressure from other sensors (CTD);
Profile = compute_fallrate_downcast(Profile);
Profile.w=Profile.w/100;

%TODO probably check nan at previous step
All_channels=fields(Profile);
% for c=1:length(All_channels)
%     wh_channels=All_channels{c};
%     Profile.(wh_channels)=fillmissing(double(Profile.(wh_channels)),'linear');
%     Profile.(wh_channels)=filloutliers(double(Profile.(wh_channels)),'linear');
% end
% 
%% define the index in the profile for each scan
total_indscan = arrayfun(@(x) (1+floor(Lscan/2)*(x-1):1+floor(Lscan/2)*(x-1)+Lscan-1),1:nbscan,'un',0);
total_w       = cellfun(@(x) nanmean(Profile.w(x)),total_indscan); 

ind_downcast = find((total_w)>.20);
nbscan=length(ind_downcast);

MS.indscan   = total_indscan(ind_downcast);
MS.nbscan    = nbscan;
MS.fmax      = fmax; % arbitrary cut off frequency usually extract from coherence spectra shear/accel 
MS.nbchannel = nb_channels;

MS.w       = cellfun(@(x) nanmean(Profile.w(x)),total_indscan(ind_downcast)); 
MS.t       = cellfun(@(x) nanmean(Profile.T(x)),total_indscan(ind_downcast)); % needed to compute Kvis 
MS.s       = cellfun(@(x) nanmean(Profile.S(x)),total_indscan(ind_downcast)); % needed to compute Kvis 
MS.pr      = cellfun(@(x) nanmean(Profile.P(x)),total_indscan(ind_downcast)); % needed to compute Kvis 
MS.time    = cellfun(@(x) nanmean(Profile.epsitime(x)),total_indscan(ind_downcast)); % needed to compute Kvis 

data=zeros(nb_channels,nbscan,Lscan);
for c=1:length(All_channels)
    wh_channels=All_channels{c};
    ind=find(cellfun(@(x) strcmp(x,wh_channels),channels));
    switch wh_channels
        case {'t1','t2','s1','s2'}
            data(ind,:,:) = cell2mat(cellfun(@(x) filloutliers(Profile.(wh_channels)(x),'center','movmedian',5),MS.indscan,'un',0)).';
        case {'a1','a2','a3'}
            data(ind,:,:) = cell2mat(cellfun(@(x) filloutliers(Profile.(wh_channels)(x),'center','movmedian',5),MS.indscan,'un',0)).';
    end
end

% compute kinematic viscosity
MS.kvis=nu(MS.s,MS.t,MS.pr);
MS.ktemp=kt(MS.s,MS.t,MS.pr).';



% Profile Power and Co spectrum and Coherence. (Coherence still needs to be averaged over few scans afterwork)
[f1,~,P11,Co12]=mod_epsi_get_profile_spectrum(data,f);
%TODO comment on the Co12 sturcutre and think about reducing the size of
%the Coherence spectra (doublon)

indf1=find(f1>=0);
indf1=indf1(1:end-1);
f1=f1(indf1);
Lf1=length(indf1);

P11= 2*P11(:,:,indf1);
P11_temp=0.*P11(1:2,:,:);
P11_shear=0.*P11(1:2,:,:);
Co12=Co12(:,:,:,indf1);
%% get MADRE filters
h_freq=get_filters_MADRE(Meta_Data,f1);

%%  get Sv for shear
Sv = [Meta_Data.epsi.s1.Sv,Meta_Data.epsi.s2.Sv]; % TODO get Sv directly from the database
% Sensitivity of probe, nominal
dTdV(1)=Meta_Data.epsi.t1.dTdV; %1/0.025 V/deg 
dTdV(2)=Meta_Data.epsi.t2.dTdV; %1/0.025 V/deg 
%% compute fpo7 filters (they are speed dependent)
Emp_Corr_fac=1;
TFtemp=cell2mat(cellfun(@(x) h_freq.FPO7(x),num2cell(MS.w),'un',0).');



nb_channel=1;
for c=1:length(All_channels)
    wh_channels=All_channels{c};
    ind=find(cellfun(@(x) strcmp(x,wh_channels),channels));
    switch wh_channels
        case{'a1','a2','a3'}
            % correct transfert functions for accel spectra
            P11(ind,:,:)=squeeze(P11(ind,:,:))./...
                (ones(nbscan,1)*h_freq.electAccel);
            nb_channel=nb_channel+1;
        case{'s1'}
            TF1 =@(x) (Sv(1).*x/(2*G)).^2 .* h_freq.shear .* haf_oakey(f1,x);     
            TFshear=cell2mat(cellfun(@(x) TF1(x),num2cell(MS.w),'un',0).');
            P11(ind,:,:) = squeeze(P11(ind,:,:)) ./ TFshear;      % vel frequency spectra m^2/s^-2 Hz^-1
            P11_shear(1,:,:) = squeeze(P11(ind,:,:)); % keep Volt spectrum for noise check
      case{'s2'}
            TF1 =@(x) (Sv(2).*x/(2*G)).^2 .* h_freq.shear .* haf_oakey(f1,x);     
            TFshear=cell2mat(cellfun(@(x) TF1(x),num2cell(MS.w),'un',0).');
            P11(ind,:,:) = squeeze(P11(ind,:,:)) ./ TFshear;      % vel frequency spectra m^2/s^-2 Hz^-1
            P11_shear(2,:,:) = squeeze(P11(ind,:,:)); % keep Volt spectrum for noise check
        case{'t1','t2'}
            if strcmp(wh_channels,'t1')
                ind_dTdV=1;
                P11_temp(1,:,:) = squeeze(P11(ind,:,:)); % keep Volt spectrum for FPO7_cutoff 
            else
                ind_dTdV=2;
                P11_temp(2,:,:) = squeeze(P11(ind,:,:)); % keep Volt spectrum for FPO7_cutoff 
            end
            P11(ind,:,:) = Emp_Corr_fac * squeeze(P11(ind,:,:)).*dTdV(ind_dTdV).^2./TFtemp; % Temperature gradient frequency spectra should be ?C^2/s^-2 Hz^-1 ???? 
    end
end

indt1=find(cellfun(@(x) strcmp(x,'t1'),channels));
indt2=find(cellfun(@(x) strcmp(x,'t2'),channels));
inds1=find(cellfun(@(x) strcmp(x,'s1'),channels));
inds2=find(cellfun(@(x) strcmp(x,'s2'),channels));
% inda1=find(cellfun(@(x) strcmp(x,'a1'),channels));
% inda2=find(cellfun(@(x) strcmp(x,'a2'),channels));
% inda3=find(cellfun(@(x) strcmp(x,'a3'),channels));

%% correct frequency shear spectra with acceleration
% Co12=abs(smoothdata(Co12(:,:,:,indf1),3,'movmean',ceil(60/tscan)));
% % find out wich acceleration channel will correct the best the shear
% % channels
% if ~isempty(inds1)
%     maxa1=max(mean(Co12(inds1,inda1-1,:,2:end),3));
%     maxa2=max(mean(Co12(inds1,inda2-1,:,2:end),3));
%     maxa3=max(mean(Co12(inds1,inda3-1,:,2:end),3));
%     if isempty(maxa1);maxa1=0;inda1=0;end
%     if isempty(maxa2);maxa2=0;inda2=0;end
%     if isempty(maxa3);maxa3=0;inda3=0;end
%     maxCor=[maxa1 maxa2 maxa3];
%     indacc=[inda1 inda2 inda3];
%     indacc=indacc(maxCor==max(maxCor));
%     % correction 
%     P11(inds1,:,:)=squeeze(P11(inds1,:,:)).*(1-squeeze(Co12(inds1,indacc-1,:,:)));
% end

% convert frequency to wavenumber
k=cell2mat(cellfun(@(x) f1/x, num2cell(MS.w),'un',0).');
dk=cell2mat(cellfun(@(x) df/x, num2cell(MS.w),'un',0));

dk_all=nanmin(nanmean(diff(k,1,2),2));
k_all=nanmin(k(:)):dk_all:nanmax(k(:));
Lk_all=length(k_all);

% temperature, vel and accell spec as function of k
P11k  = P11.* shiftdim(repmat(ones(nb_channels,1)*MS.w,[1,1,Lf1]),3);   

MS.f   = f1;
MS.k   = k_all;
MS.Pf  = P11;
MS.Co12 = Co12;
% Set kmax for integration to highest bin below pump spike,
% which is between 49 and 52 Hz in a 1024-pt spectrum
MS.kmax=MS.fmax./MS.w; % Lowest estimate below pump spike in 1024-pt record


% get FPO7 channel average noise to compute chi
switch Meta_Data.MAP.temperature
    case 'Tdiff'
        FPO7noise=load([Meta_Data.CALIpath 'FPO7_noise.mat'],'n0','n1','n2','n3');
    otherwise
        FPO7noise=load([Meta_Data.CALIpath 'FPO7_notdiffnoise.mat'],'n0','n1','n2','n3');
end

% calc epsilon by integrating to k with 90% variance of Panchev spec
% unless spectrum is noisy at lower k.
% Check that data window > 0.5 m, as needed for initial estimate
%MS.PphiT_k=zeros(nbscan,).*nan;
MS.PphiT_k=zeros(nbscan,Lk_all,2).*nan;
MS.Pshear_k=zeros(nbscan,Lk_all,2).*nan;
%MS.Paccell_k=zeros(nbscan,Lk_all,3).*nan;
for j=1:nbscan
    fprintf('scan %i over %i \n',j,nbscan)
    if ~isempty(indt1)
        MS.PphiT_k(j,:,1)  = (2*pi*k_all).^2 .* interp1(k(j,:),squeeze(P11k(indt1,j,:)),k_all);        % T1_k spec  as function of k
    end
    if ~isempty(indt2)
        MS.PphiT_k(j,:,2)  = (2*pi*k_all).^2 .* interp1(k(j,:),squeeze(P11k(indt2,j,:)),k_all);        % T2_k spec  as function of k
    end
    if ~isempty(inds1)
        MS.Pshear_k(j,:,1) = (2*pi*k_all).^2 .* interp1(k(j,:),squeeze(P11k(inds1,j,:)),k_all);        % shear spec  as function of k
    end
    if ~isempty(inds2)
        MS.Pshear_k(j,:,2) = (2*pi*k_all).^2 .* interp1(k(j,:),squeeze(P11k(inds2,j,:)),k_all);        % shear spec  as function of k
    end
%     if ~isempty(inda1)
%         MS.Paccel_k(j,:,1)     =  interp1(k(j,:),squeeze(P11k(inda1,j,:)),k_all);        % Accel 1 spec  as function of k
%     end
%     if ~isempty(inda2)
%         MS.Paccel_k(j,:,2)     =  interp1(k(j,:),squeeze(P11k(inda2,j,:)),k_all);        % Accel 2 spec  as function of k
%     end
%     if ~isempty(inda3)
%         MS.Paccel_k(j,:,3)     =  interp1(k(j,:),squeeze(P11k(inda3,j,:)),k_all);        % Accel 3 spec  as function of k
%     end
    % compute epsilon in eps1_mmp
    if ~isempty(inds1)
        [MS.epsilon(j,1),MS.kc(j,1)]=eps1_mmp(k_all,MS.Pshear_k(j,:,1),MS.kvis(j),dk(j),MS.kmax(j)); 
        [kpan,Ppan] = panchev(MS.epsilon(j,1),MS.kvis(j));
        MS.Ppan(j,:,1)=interp1(kpan,Ppan,k_all);
    end
    if ~isempty(inds2)
        [MS.epsilon(j,2),MS.kc(j,2)]=eps1_mmp(k_all,MS.Pshear_k(j,:,2),MS.kvis(j),dk(j),MS.kmax(j));
        [kpan,Ppan] = panchev(MS.epsilon(j,2),MS.kvis(j));
        MS.Ppan(j,:,2)=interp1(kpan,Ppan,k_all);
    end

     if ~isempty(indt1)
         MS.fc_index(j,1)=FPO7_cutoff(f1,squeeze(P11_temp(1,j,:)).',FPO7noise);
        MS.chi(j,1)=6*MS.ktemp(j)*dk(j).*nansum(MS.PphiT_k(j,1:MS.fc_index(j,1),1));
    end
    if ~isempty(indt2)
        MS.fc_index(j,2)=FPO7_cutoff(f1,squeeze(P11_temp(2,j,:)).',FPO7noise);
        MS.chi(j,2)=6*MS.ktemp(j)*dk(j).*nansum(MS.PphiT_k(j,1:MS.fc_index(j,2),2));
    end
    
    if dsp==1
        n0=FPO7noise.n0; n1=FPO7noise.n1; n2=FPO7noise.n2; n3=FPO7noise.n3;
        logf=log10(f1);
        noise=n0+n1.*logf+n2.*logf.^2+n3.*logf.^3;
        shearnoise=load([Meta_Data.CALIpath 'shear_noise.mat'],'n0s','n1s','n2s','n3s');
        n0s=shearnoise.n0s; n1s=shearnoise.n1s; n2s=shearnoise.n2s; n3s=shearnoise.n3s;
        snoise=n0s+n1s.*logf+n2s.*logf.^2+n3s.*logf.^3;
        
        figure(10)
        ax(1)=subplot(211);
        loglog(f1,squeeze(P11_temp(1,j,:)),'r')
        hold(ax(1),'on')
        loglog(f1,squeeze(P11_temp(2,j,:)),'b')
        if ~isempty(indt1)
            loglog(f1(1:MS.fc_index(j,1)),squeeze(P11_temp(1,j,1:MS.fc_index(j,1))),'c')
        else
            loglog(f1(1:MS.fc_index(j,2)),squeeze(P11_temp(2,j,1:MS.fc_index(j,2))),'c')
        end
        loglog(f1,10.^noise,'k')
        ylim([1e-15 1e-5])
        xlim(f1([1 end]))
        hold(ax(1),'off')
        ylabel('t_{1,2} (V^2/Hz)','fontsize',20)
        set(ax(1),'fontsize',15)
        legend('t1 raw','t2','t1 signal','MADRE noise','location','southwest')
        set(ax(1),'Xscale','log','Yscale','log')
        
        ax(2)=subplot(212);
        loglog(f1,squeeze(P11_shear(1,j,:)),'r')
        hold(ax(2),'on')
        loglog(f1,squeeze(P11_shear(2,j,:)),'b')
        if ~isempty(inds1)
            ind_s1=find(k(j,:)<MS.kc(j,1));
            loglog(f1(ind_s1),squeeze(P11_shear(1,j,ind_s1)),'c')
        else
            ind_s2=find(k(j,:)<MS.kc(j,1));
            loglog(f1(ind_s2),squeeze(P11_shear(2,j,ind_s2)),'c')
        end
        loglog(f1,10.^snoise,'k')
        ylim([1e-15 1e-1])
        xlim(f1([1 end]))
        hold(ax(2),'off')
        set(gca,'Xscale','log','Yscale','log')
        ylabel('s_{1,2} (V^2/Hz)','fontsize',20)
        set(ax(2),'fontsize',15)
        legend('s1 raw','s2','s1 signal','MADRE noise','location','southwest')
        pause(.1)
        %     cla(ax(1))
        %     cla(ax(2))
    end
end


