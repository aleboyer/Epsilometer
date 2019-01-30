function create_profiles_EPSIWW(Meta_Data)

%  split times series into profiles
%
%  input: Meta_Data
%  created with Meta_Data=create_Meta_Data(file). Meta_Data contain the
%  path to calibration file and EPSI configuration needed to process the
%  epsi data
%
%  Created by Arnaud Le Boyer on 7/28/18.

name_rbr=[Meta_Data.mission '_rbr_' Meta_Data.deployment];
ctdfile=[Meta_Data.CTDpath 'Profiles_' name_rbr];
epsifile=[Meta_Data.Epsipath 'epsi_' Meta_Data.deployment];


SD  =load(epsifile);
CTD = load(ctdfile);

CTDProfile=CTD.RBRprofiles.dataup;
%Epsi.Sensor5 = Epsi.Sensor1*nan;
EpsiProfile  = get_cast_epsiWW(SD,CTDProfile);
for i=1:length(CTDProfile)
    CTDProfile{i}.ctdtime=CTDProfile{i}.time;
end


% plot(SD.epsitime,SD.s2)
% hold on
% for i=1:length(EpsiProfile)
%     plot(EpsiProfile{i}.epsitime,EpsiProfile{i}.s2)
% end
% 
save([Meta_Data.L1path 'Profiles_' Meta_Data.deployment '.mat'],'CTDProfile','EpsiProfile','-v7.3');


