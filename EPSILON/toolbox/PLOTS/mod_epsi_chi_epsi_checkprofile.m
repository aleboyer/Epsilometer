%function mod_epsi_chi_epsi_checkprofile(MS,Meta_Data)
close all
l=2;
fontsize=20;
titre={sprintf('%s',Meta_Data.deployment),sprintf('Cast %i',l)};
fig=figure(2);
set(gcf,'Position',[500 100 2000 1500])

% acceleration and coherence with shear
sma1=squeeze(nanmean(MS{l}.Pf(6,:,:),2));
sma2=squeeze(nanmean(MS{l}.Pf(7,:,:),2));
sma3=squeeze(nanmean(MS{l}.Pf(8,:,:),2));
sms1=squeeze(nanmean(MS{l}.Pf(3,:,:),2));
sms2=squeeze(nanmean(MS{l}.Pf(4,:,:),2));

Co11=abs(squeeze(nanmean(MS{l}.Co12(3,5,:,:),3)));
Co12=abs(squeeze(nanmean(MS{l}.Co12(3,6,:,:),3)));
Co13=abs(squeeze(nanmean(MS{l}.Co12(3,7,:,:),3)));
Co21=abs(squeeze(nanmean(MS{l}.Co12(4,5,:,:),3)));
Co22=abs(squeeze(nanmean(MS{l}.Co12(4,6,:,:),3)));
Co23=abs(squeeze(nanmean(MS{l}.Co12(4,7,:,:),3)));

dTdV=[Meta_Data.epsi.t1.dTdV Meta_Data.epsi.t2.dTdV];

% noise floor
logf=log10(MS{l}.f);
h_freq=get_filters_MADRE(Meta_Data,MS{l}.f);
NOISE=load('/Users/aleboyer/ARNAUD/SCRIPPS/EPSILOMETER/CALIBRATION/ELECTRONICS/comparison_temp_granite_sproul.mat');
spec_notdiff=interp1(NOISE.k_granite,NOISE.spec_granite,MS{l}.f);
FPO7noise=load([Meta_Data.CALIpath 'FPO7_noise.mat'],'n0','n1','n2','n3');
n0=FPO7noise.n0; n1=FPO7noise.n1; n2=FPO7noise.n2; n3=FPO7noise.n3;
shearnoise=load([Meta_Data.CALIpath 'shear_noise.mat'],'n0s','n1s','n2s','n3s');
n0s=shearnoise.n0s; n1s=shearnoise.n1s; n2s=shearnoise.n2s; n3s=shearnoise.n3s;
noise_tdiff0=10.^(n0+n1.*logf+n2.*logf.^2+n3.*logf.^3);
%noise_tdiff=noise_tdiff0.*dTdV(1).^2./h_freq.electFPO7.^2./h_freq.Tdiff.^2;

noise_notdiff=spec_notdiff.*dTdV(1).^2./h_freq.electFPO7.^2;

snoise=10.^(n0s+n1s.*logf+n2s.*logf.^2+n3s.*logf.^3);


% % movie stuff
v = VideoWriter(sprintf('%s_cast%i%s',Meta_Data.deployment,l,'.avi'));
v.FrameRate=5;
open(v)

% TG spectra 
ax(1)=axes('Position',[.05 .06 .45 .6]);
% chi profiles
ax(2)=axes('Position',[.066 .65 .08 .3]);
% epsi profiles
ax(3)=axes('Position',[.15 .65 .08 .3]);
% T-S profiles
ax(4)=axes('Position',[.235 .65 .08 .3]);
% w profile
ax(5)=axes('Position',[.32 .65 .08 .3]);
%  shear spectra 
ax(6)=axes('Position',[.51 .06 .44 .6]);
%  accel spectra 
ax(7)=axes('Position',[.7 .83 .24 .15]);
%  coherence spectra 
ax(8)=axes('Position',[.7 .67 .24 .15]);

a=2;
plot(ax(a),MS{l}.chi,MS{l}.pr)
a=3;
plot(ax(a),MS{l}.epsilon,MS{l}.pr)
a=4;
%[ax1,hl1,hl2]=plotxx(MS{l}.t,MS{l}.pr,MS{l}.s,MS{l}.pr,{'',''},{'',''},ax(a));
a=5;
plot(ax(a),MS{l}.w,MS{l}.pr)

a=8;
semilogx(ax(a),MS{l}.f,Co11)
hold(ax(a),'on')
semilogx(ax(a),MS{l}.f,Co12)
semilogx(ax(a),MS{l}.f,Co13)

grid(ax(a),'on')
legend(ax(a),'a1','a2','a3','location','northwest')
ax(a).YAxisLocation='right';
xlim(ax(a),MS{l}.f([1 end]))
ylim(ax(a),[0 1])
ax(a).FontSize=fontsize;
ax(a).XScale='log';
ax(a).YScale='linear';
ylabel(ax(a),'Coherence s1','fontsize',fontsize)
xlabel(ax(a),'Hz','fontsize',fontsize)
set(ax(a),'Xtick',[1 10 100])


annotation('textbox',...
    [.545 .68 .16 .29],...
    'String',{Meta_Data.mission,...
    Meta_Data.vehicle_name,...
    Meta_Data.deployment,...
    Meta_Data.path_mission,...
    ['MADRE ' Meta_Data.MADRE.SN ' rev ' Meta_Data.MADRE.rev],...
    ['MAP '   Meta_Data.MAP.SN   ' rev ' Meta_Data.MAP.rev],...
    [Meta_Data.aux1.name ' ' Meta_Data.aux1.SN],...
    sprintf('s1 - SN: %s - Sv:%s - %s - %s', ...
        Meta_Data.epsi.s1.SN,Meta_Data.epsi.s1.Sv,...
        Meta_Data.epsi.s1.ADCfilter,Meta_Data.epsi.s1.ADCconf),...
    sprintf('s2 - SN: %s - Sv:%s - %s - %s', ...
        Meta_Data.epsi.s2.SN,Meta_Data.epsi.s2.Sv,...
        Meta_Data.epsi.s2.ADCfilter,Meta_Data.epsi.s2.ADCconf),...
    sprintf('t1 - SN: %s - dTdV: %u - %s - %s', ...
        Meta_Data.epsi.t1.SN,Meta_Data.epsi.t1.dTdV,...
        Meta_Data.epsi.t1.ADCfilter,Meta_Data.epsi.t1.ADCconf),...
    sprintf('t2 - SN: %s - dTdV: %u - %s - %s', ...
        Meta_Data.epsi.t2.SN,Meta_Data.epsi.t2.dTdV,...
        Meta_Data.epsi.t2.ADCfilter,Meta_Data.epsi.t2.ADCconf),...
    },...
    'FontSize',14,...
    'FontName','Arial',...
    'LineStyle','-',...
    'EdgeColor','k',...
    'LineWidth',2,...
    'BackgroundColor',[0.9  0.9 0.9],...
    'Color','k');
    a=7;
    loglog(ax(a),MS{l}.f,sma1)
    hold(ax(a),'on')
    loglog(ax(a),MS{l}.f,sma2)
    loglog(ax(a),MS{l}.f,sma3)
    loglog(ax(a),MS{l}.f,sms1,'m')
    set(ax(a),'Xticklabel','')
    grid(ax(a),'on')
    legend(ax(a),'a1','a2','a3','s1','location','southwest')
    set(ax(a),'Xticklabel','')
    ax(a).YAxisLocation='right';
    xlim(ax(a),MS{l}.f([1 end]))
    ylim(ax(a),[1e-10 1e-3])
    ax(a).XScale='log';
    ax(a).YScale='log';
    ax(a).FontSize=fontsize;
    set(ax(a),'Xtick',[1 10 100])
    ylabel(ax(a),'g^2/Hz','fontsize',fontsize)
  
    
dTdV=[Meta_Data.epsi.t1.dTdV,Meta_Data.epsi.t2.dTdV];
Sv=[str2double(Meta_Data.epsi.s1.Sv),str2double(Meta_Data.epsi.s2.Sv)];
Gr=9.81;
for k=1:length(MS{l}.kvis)
    % noise stuff
    k_noise=MS{l}.f./MS{l}.w(k);
    noise_tdiff=noise_tdiff0.*dTdV(1).^2./h_freq.FPO7(MS{l}.w(k));
    tdiffnoise_k= (2*pi*k_noise).^2 .* noise_tdiff.*MS{l}.w(k);        % T1_k spec  as function of k
    noise_notdiff=noise_notdiff./h_freq.magsq(MS{l}.w(k));
    notdiffnoise_k= (2*pi*k_noise).^2 .* noise_notdiff.*MS{l}.w(k);        % T1_k spec  as function of k
    

    TFshear=(Sv(1).*MS{l}.w(k)/(2*Gr)).^2 .* h_freq.shear.* haf_oakey(MS{l}.f,MS{l}.w(k));
    snoise_k= (2*pi*k_noise).^2 .* snoise.*MS{l}.w(k)./TFshear;        % T1_k spec  as function of k

    
    [kbatch,Pbatch] = batchelor(MS{l}.epsilon(k,1),MS{l}.chi(k,2), ...
        MS{l}.kvis(k),MS{l}.ktemp(k));
    smTG1=smoothdata(MS{l}.PphiT_k(k,:,1),'movmean',10);
    smTG2=smoothdata(MS{l}.PphiT_k(k,:,2),'movmean',10);
    
    loglog(ax(1),MS{l}.k,MS{l}.PphiT_k(k,:,1),'--','Color',.8*[.5 1 .5])
    hold(ax(1),'on')
    loglog(ax(1),MS{l}.k,smTG1,'Color',.8*[.5 1 .7],'linewidth',2)
    loglog(ax(1),MS{l}.k,MS{l}.PphiT_k(k,:,2),'--','Color',.7*[1 1 1])
    loglog(ax(1),MS{l}.k,smTG2,'Color',.3*[1 1 1],'linewidth',2)
    loglog(ax(1),k_noise,tdiffnoise_k,'c','linewidth',1)
    loglog(ax(1),k_noise,notdiffnoise_k,'c--','linewidth',1)
    scatter(ax(1),MS{l}.k(MS{l}.fc_index(k,1)),smTG1(MS{l}.fc_index(k,1)),500,.8*[.5 1 .7],'filled','d','MarkerEdgeColor','y','linewidth',3)
    scatter(ax(1),MS{l}.k(MS{l}.fc_index(k,2)),smTG2(MS{l}.fc_index(k,2)),500,.3*[1 1 1],'filled','p','MarkerEdgeColor','y','linewidth',3)
    loglog(ax(1),k_noise,noise_tdiff0,'g','linewidth',1)
    
    loglog(ax(1),kbatch,Pbatch,'m')
    hold(ax(1),'off')
    set(ax(1),'Xscale','log','Yscale','log')
    set(ax(1),'fontsize',fontsize)
    legend(ax(1),'t1','t1smooth','t2','t2smooth','Tdiff-noise','noTdiff-noise','t1_{cutoff}','t2_{cutoff}','batchelor','location','southwest')
    xlim(ax(1),[6e-1 400])
    ylim(ax(1),[1e-10 1e-1])
    grid(ax(1),'on')
    xlabel(ax(1),'k (cpm)','fontsize',fontsize)
    ylabel(ax(1),'\phi^2_{TG} (C^2 m^{-2} / cpm)','fontsize',fontsize)
    %title(ax(1),,'position',[30 0.2]) % postion in x-y units 

    %plot chi
    a=2;
%    plot(ax(a),MS{l}.chi,MS{l}.pr)
    hold(ax(a),'on')
    ax(a).YDir='reverse';
    A=scatter(ax(a),MS{l}.chi(k,1),MS{l}.pr(k),100,'k','d','filled');
    B=scatter(ax(a),MS{l}.chi(k,2),MS{l}.pr(k),100,'k','p','filled');
    hold(ax(a),'off')
    legend(ax(a),'t1','t2','location','northeast')
    set(ax(a),'Xscale','log','Yscale','linear')
    set(ax(a),'Xtick',[1e-12 1e-10 1e-8 1e-6 1e-4])
    xlim(ax(a),[1e-12 max(MS{l}.chi(:))])
    ylim(ax(a),[min(MS{l}.pr) max(MS{l}.pr)])
    set(ax(a),'fontsize',15)
    ylabel(ax(a),'Depth (m)','fontsize',fontsize)
    xlabel(ax(a),'\chi (K^2 s^{-1}) ','fontsize',fontsize)

    %plot epsilon
    a=3;
    %plot(ax(a),MS{l}.epsilon,MS{l}.pr)
    hold(ax(a),'on')
    ax(a).YDir='reverse';
    C=scatter(ax(a),MS{l}.epsilon(k,1),MS{l}.pr(k),100,'k','d','filled');
    D=scatter(ax(a),MS{l}.epsilon(k,2),MS{l}.pr(k),100,'k','p','filled');
    hold(ax(a),'off')
    legend(ax(a),'s1','s2','location','northeast')
    set(ax(a),'Xscale','log','Yscale','linear')
    set(ax(a),'Xtick',[1e-12 1e-10 1e-8 1e-6 1e-4])
    xlim(ax(a),[1e-12 max(MS{l}.epsilon(:))])
    ylim(ax(a),[min(MS{l}.pr) max(MS{l}.pr)])
    set(ax(a),'fontsize',15)
    set(ax(a),'Yticklabel','')
    xlabel(ax(a),'\epsilon (W kg^{-1}) ','fontsize',fontsize)

    %plot temperature
    a=4;
    %plot(ax(a),MS{l}.t,MS{l}.pr)
    axes(ax(a));
    [ax1,hl1,hl2]=plotxx(MS{l}.t,MS{l}.pr,MS{l}.s,MS{l}.pr,{'',''},{'',''});
    %hold(ax(1),'on')
    hold(ax1(1),'on')
    ax1(1).YDir='reverse';
    E=scatter(ax1(1),MS{l}.t(k),MS{l}.pr(k),100,'k','d','filled');
    hold(ax1(1),'off')
    hold(ax1(2),'on')
    F=scatter(ax1(2),MS{l}.s(k),MS{l}.pr(k),100,'k','p','filled');
    %hold(ax(1),'off')
    hold(ax1(2),'off')
    %legend(ax(a),'T','location','northeast')
    set(ax1(1),'Xscale','linear','Yscale','linear')
    set(ax1(1),'Xtick',floor(min(MS{l}.t)):2:floor(max(MS{l}.t)))
    xlim(ax1(1),[min(MS{l}.t) max(MS{l}.t)])
    ylim(ax1(1),[min(MS{l}.pr) max(MS{l}.pr)])
    xlim(ax1(2),[min(MS{l}.s) max(MS{l}.s)])
    ylim(ax1(2),[min(MS{l}.pr) max(MS{l}.pr)])
    set(ax1(1),'fontsize',15)
    set(ax1(1),'Yticklabel','')
    xlabel(ax1(1),'SBE T (C) ','fontsize',fontsize)
    
    
    set(ax1(2),'Xscale','linear','Yscale','linear')
    set(ax1(2),'Xtick',floor(min(MS{l}.s)):.3:floor(max(MS{l}.s)))
    xlim(ax1(2),[min(MS{l}.s) max(MS{l}.s)])
    ylim(ax1(2),[min(MS{l}.pr) max(MS{l}.pr)])
    set(ax1(2),'fontsize',15)
    set(ax1(2),'Yticklabel','')
    set(ax1(2),'Yticklabel','')
    ax1(2).YDir='reverse';
    xlabel(ax1(2),'SBE S (psu) ','fontsize',fontsize)

    %plot speed
    a=5;
    %plot(ax(a),MS{l}.w,MS{l}.pr)
    hold(ax(a),'on')
    ax(a).YDir='reverse';
    G=scatter(ax(a),MS{l}.w(k),MS{l}.pr(k),100,'k','d','filled');
    hold(ax(a),'off')
    legend(ax(a),'w','location','northeast')
    set(ax(a),'Xscale','linear','Yscale','linear')
    set(ax(a),'Xtick',[.4  .6 .8 1])
    xlim(ax(a),[.4 max(MS{l}.w)])
    ylim(ax(a),[min(MS{l}.pr) max(MS{l}.pr)])
    set(ax(a),'fontsize',15)
    set(ax(a),'Yticklabel','')
    xlabel(ax(a),'speed (m s^{-1}) ','fontsize',fontsize)

    
    %plot shear
    a=6;
    [kpan,Ppan] = panchev(MS{l}.epsilon(k,1),MS{l}.kvis(k));
    smS1=smoothdata(MS{l}.Pshear_k(k,:,1),'movmean',10);
    smS2=smoothdata(MS{l}.Pshear_k(k,:,2),'movmean',10);
    kcindex1=find(MS{l}.k<MS{l}.kc(k,1),1,'last');
    kcindex2=find(MS{l}.k<MS{l}.kc(k,2),1,'last');
    
    loglog(ax(a),MS{l}.k,MS{l}.Pshear_k(k,:,1),'--','Color',.8*[.5 1 .5])
    hold(ax(a),'on')
    loglog(ax(a),MS{l}.k,smS1,'Color',.8*[.5 1 .7],'linewidth',2)
    loglog(ax(a),MS{l}.k,MS{l}.Pshear_k(k,:,2),'--','Color',.7*[1 1 1])
    loglog(ax(a),MS{l}.k,smS2,'Color',.3*[1 1 1],'linewidth',2)
    loglog(ax(a),k_noise,snoise_k,'c','linewidth',1)
    scatter(ax(a),MS{l}.k(kcindex1),smS1(kcindex1),500,.8*[.5 1 .7],'filled','d','MarkerEdgeColor','c','linewidth',2)
    scatter(ax(a),MS{l}.k(kcindex2),smS2(kcindex2),500,.3*[1 1 1],'filled','p','MarkerEdgeColor','c','linewidth',2)
    
    loglog(ax(a),kpan,Ppan,'m')
    hold(ax(a),'off')
    set(ax(a),'Xscale','log','Yscale','log')
    set(ax(a),'fontsize',fontsize)
    legend(ax(a),'s1','s1smooth','s2','s2smooth','noise','s1_{cutoff}','s2_{cutoff}','Panchev','location','southwest')
    xlim(ax(a),[6e-1 400])
    ylim(ax(a),[1e-10 1e-1])
    grid(ax(a),'on')
    xlabel(ax(a),'k (cpm)','fontsize',fontsize)
    ylabel(ax(a),'\phi^2_{shear} (s^{-2} / cpm)','fontsize',fontsize)
    ax(6).YAxisLocation='right';

    
    
    annotation('textbox',...
    [.41 .7 .13 .27],...
    'String',{datestr(MS{l}.time(k)),...
              sprintf('pressure=%3.1f db',MS{l}.pr(k)),...
              sprintf('temperature=%2.2f (C)',MS{l}.t(k)),...
              sprintf('salinity=%2.2f (psu)',MS{l}.s(k)),...
              sprintf('kinematic viscosity =%1.2e m^2 s^{-1}',MS{l}.kvis(k)),...
              sprintf('scalar diffusivity =%1.2e m^2 s^{-1}',MS{l}.ktemp(k)),' ',...
              ['\epsilon_{1,2}' sprintf('=%1.2e, %1.2e (W kg^{-1})',MS{l}.epsilon(k,1),MS{l}.epsilon(k,2))],...
              ['\chi_{1,2}'     sprintf('=%1.2e, %1.2e (K^2 s^{-1})',MS{l}.chi(k,1),MS{l}.chi(k,2))],...
              },...
    'FontSize',14,...
    'FontName','Arial',...
    'LineStyle','-',...
    'EdgeColor','k',...
    'LineWidth',2,...
    'BackgroundColor',[0.9  0.9 0.9],...
    'Color','k');


    pause(.001)
    % movie stuff
    frame=getframe(gcf);
    writeVideo(v,frame)
    delete(A);
    delete(B);
    delete(C);
    delete(D);
    delete(E);
    delete(F);
    delete(G);
   
end
% movie stuff
close(v)
