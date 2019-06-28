function epsi = mod_read_epsi_raw(filename,Meta_Data)
% SN_READ_EPSI_RAW - reads epsi raw data
%
% SN_READ_EPSI_RAW(FILENAME) returns a EPSI structure of variables described
% for EPSI data files
% 
% SN_READ_EPSI_RAW(DIRNAME) reads all *.epsi, *.dat, *.bin files in the directory DIRNAME
% 
% SN_READ_EPSI_RAW({FILE1, FILE2,...}) reads all files indicated
%
% this function does not sort data yet nor does it have data checksum
%
% Created 2018/10/15 San Nguyen
%
% add Meta_Data to automatize unipolar and bipolar config of the ADC and the
% number channels
% modified 2018/12/20 Arnaud Le Boyer 
%

% check if it is a single file or a directory and a set of files
if ischar(filename) % dir or file
    switch exist(filename,'file')
        case 2 % if it is a file
            fid = fopen(filename,'r');
            epsi = mod_read_epsi_raw(fid,Meta_Data);
            fclose(fid);
        case 7 % if it is a directory
            my_epsi_file = [];
            my_epsi_file = [my_epsi_file; dir(fullfile(filename, '*.epsi'))];
            my_epsi_file = [my_epsi_file; dir(fullfile(filename, '*.bin'))];
            my_epsi_file = [my_epsi_file; dir(fullfile(filename, '*.dat'))];
            if isempty(my_epsi_file)
                epsi = [];
                return
            else
                % prepare to read all files
                epsi = cell(size(my_epsi_file));
                % read the files in the directory
                for i = 1:length(my_epsi_file)
                    disp(['reading ' my_epsi_file(i).name]);
                    epsi{i} = mod_read_epsi_raw(fullfile(filename,my_epsi_file(i).name),Meta_Data);
                end
                % combine all files into one MET structure
                epsi = mod_combine_epsi(epsi{:});
            end
        otherwise
            error('MATLAB:mod_read_epsi_raw:wrongFILENAME','Invalid file specified.');
    end
elseif iscellstr(filename) % cell of files
    % prepare to read all files
    epsi = cell(size(filename));
    % read all files
    for i = 1:length(filename)
        disp(['reading ' filename{i}]);
        epsi{i} = mod_read_epsi_raw(filename{i},Meta_Data);
    end
    % combine all files into one epsi structure
    epsi = mod_combine_epsi(epsi{:});
else
    
    if (filename<1)
        error('MATLAB:mod_read_epsi_raw:wrongFID','FID is invalid');
    end
    
    epsi = mod_read_epsi_raw_file(filename,Meta_Data);
    
    return
end

end

% reading epsi files through FID
function EPSI = mod_read_epsi_raw_file(fid,Meta_Data)
tic
% make sure the file marker begins at the start
EPSI = epsi_ascii_parseheader(fid);

if ~isempty(EPSI)
    %convert time to MATLAB time
    if EPSI.header.offset_time < 0
        EPSI.header.offset_time = epsi_ascii_correct_negative_time(EPSI.header.offset_time)/86400+datenum(1970,1,1);
    else
        EPSI.header.offset_time = EPSI.header.offset_time/86400+datenum(1970,1,1);
    end
    if EPSI.header.system_time < 0
        EPSI.header.system_time = epsi_ascii_correct_negative_time(EPSI.header.system_time)/86400/100+EPSI.header.offset_time;
    else
        EPSI.header.system_time = EPSI.header.system_time/86400/100+EPSI.header.offset_time;
    end
else
% isfield(Meta_Data,'SBEcal')
    EPSI.header=Meta_Data.SBEcal;
end

%TODO get rid of ths offset  
switch Meta_Data.PROCESS.recording_mod
    case 'STREAMING'
    offset1=13;
    case 'SD'
    offset1=2;
end


fseek(fid,0,1);
fsize = ftell(fid);
frewind(fid);

str = fread(fid,'*char')';



%%
%clc;
% tic
% get MADRE position beginning of datablock
ind_madre = strfind(str,'$MADRE');
% get aux1 position beginning of SBE block if present
%ind_aux1 = strfind(str,'$AUX1');
is_aux1 = contains(str,'$AUX1');
toc

%find header length from the 1st MADRE block
header_length=strfind(str(ind_madre(1):ind_madre(1)+72),'$');
header_length=header_length(2);
switch header_length
    case 71 % ALB: I added the musecond timestamp in third position. So the header is longer
        firmware_version='microsecond';
    otherwise
        firmware_version='SODA';
end


% hard coded value to define MADRE block Header
madre.epsi_stamp_length = 8;
madre.epsi_time_length = 8;
madre.alt_time_length = 4;
madre.aux_chksum_length = 8;
madre.map_chksum_length = 8;
madre.fsync_err_length = 8;
madre.offset = 0;
madre.name_length = 6;

switch firmware_version
    case 'microsecond' % ALB: I added the musecond timestamp in third position. So the header is longer
        madre.epsi_mutime_length = 8;
        madre.epsi_stamp_offset  = -1+madre.name_length;
        madre.epsi_time_offset   = madre.epsi_stamp_offset+madre.epsi_stamp_length+1;
        madre.epsi_mutime_offset = madre.epsi_time_offset+madre.epsi_time_length+1;
        madre.fsync_err_offset    = madre.epsi_mutime_offset+madre.epsi_time_length+1;
        madre.aux_chksum_offset  = madre.fsync_err_offset+madre.fsync_err_length+1;
        madre.alt_time_offset    = madre.aux_chksum_offset+madre.aux_chksum_length+[0 4]+1;
        madre.map_chksum_offset  = madre.alt_time_offset(end)+madre.alt_time_length+1;
    otherwise
        % hard coded value to define MADRE block Header
        
        % ALB commented San's version
%         madre.epsi_stamp_offset = -1+madre.name_length;
%         madre.epsi_time_offset  = 8+madre.name_length;
%         madre.alt_time_offset   = [17,21]+madre.name_length;
%         madre.fsync_err_offset  = 35+madre.name_length;
%         madre.aux_chksum_offset = 26+madre.name_length;
%         madre.map_chksum_offset = 44+madre.name_length;
        
        madre.epsi_stamp_offset  = -1+madre.name_length;
        madre.epsi_time_offset   = madre.epsi_stamp_offset+madre.epsi_stamp_length+1;
        madre.fsync_err_offset    = madre.epsi_time_offset+madre.epsi_time_length+1;
        madre.aux_chksum_offset  = madre.fsync_err_offset+madre.fsync_err_length+1;
        madre.alt_time_offset    = madre.aux_chksum_offset+madre.aux_chksum_length+[0 4]+1;
        madre.map_chksum_offset  = madre.alt_time_offset(end)+madre.alt_time_length+1;
        
end

madre.header_offset  = madre.map_chksum_offset+madre.map_chksum_length+2;

% % define offset if aux1 is present
% if isempty(ind_aux1)
%     aux1.offset = nan();
% else
%     aux1.offset = madre.offset+ ...
%                   madre.name_length+ ...
%                   madre.epsi_stamp_length+1+ ...
%                   madre.epsi_time_length+1+ ...
%                   madre.alt_time_length*2+1+ ...
%                   madre.aux_chksum_length+1+ ...
%                   madre.fsync_err_length+1+ ...
%                   madre.map_chksum_length+2-1;
%               
%      aux1.offset  = madre.map_chksum_offset+madre.map_chksum_length+2;
% 
%               
% end%60; %madre.offset+madre.name_length+madre.epsi_stamp_length+1+madre.epsi_time_length+1+madre.alt_time_length*4+2+madre.aux_chksum_length+1+madre.map_chksum_length+2-1;
% aux1.name_length = 5;
% aux1.stamp_offset = (0:8)*33+aux1.name_length+aux1.offset;
% aux1.sbe_offset = (0:8)*33+9+aux1.name_length+aux1.offset;
% 
% % e.g 00000F2E,052C2409E6F3080D7A4DAF
% aux1.stamp_length = 8; % length of epsi sample number linked to SBE sample.
% aux1.sbe_length = 22;  % length of SBE sample.

% define offset if aux1 is present
if is_aux1
    aux1.name_length  = 5;
    aux1.stamp_length = 8; % length of epsi sample number linked to SBE sample.
    aux1.sbe_length   = 22;  % length of SBE sample.
    aux1.nbsample     = 9;
    aux1_sample_length= aux1.stamp_length + 1 + aux1.sbe_length + 2;
    % e.g 00000F2E,052C2409E6F3080D7A4DAF
    aux1.stamp_offset  = madre.header_offset + (0:aux1.nbsample-1)*aux1_sample_length+aux1.name_length;
    aux1.sbe_offset    = madre.header_offset + (0:aux1.nbsample-1)*aux1_sample_length+(aux1.stamp_length + 1)+aux1.name_length;
end


% ALB: comment San's version
% if isnan(aux1.offset)
%     epsi.offset(end) = madre.offset+madre.name_length+madre.epsi_stamp_length+1+madre.epsi_time_length+1+madre.alt_time_length*2+1+madre.aux_chksum_length+1+madre.fsync_err_length+1+madre.map_chksum_length+2-1;
% else
%     epsi.offset(end) = aux1.offset+aux1.name_length+(aux1.stamp_length+1+aux1.sbe_length+2)*9;
% end
if is_aux1
    epsi.offset = aux1.stamp_offset+aux1_sample_length;
else
    epsi.offset = madre.header_offset;
end


epsi.name_length = 5; % length of epsi block header ($EPSI).
epsi.nbsamples = 160;   % number of sample in 1 epsi block.
epsi.nchannels = Meta_Data.PROCESS.nb_channels; % number of channels defined by user.
epsi.sample_freq = 320; % hardcoded sampling rate can do better when we will use usecond resolution for the timer. 
epsi.sample_period = 1/epsi.sample_freq;
epsi.bytes_per_channel = 3; % length of an ADC sample = length of one channel sample. In bytes MSBF (TO DO check MSBF) 
epsi.total_length = epsi.nbsamples*epsi.nchannels*epsi.bytes_per_channel; % length of an EPSI block

% find the non corrupted (right length)
%!!!!!!!! VERY IMPORTANT to remember !!!!! 
%indblock=ind_madre(diff(ind_madre)==median(diff(ind_madre))); %TO DO figure that exact math for the block length
indblock=ind_madre(diff(ind_madre)==epsi.offset(end)+epsi.name_length+epsi.total_length+offset1+1);
NBblock=numel(indblock);

% initialize arrays and structures.
if(isfield(EPSI,'header'))
    system.time = char(zeros(NBblock,11));
end

madre.epsi_stamp = char(zeros(NBblock,madre.epsi_stamp_length));
madre.epsi_time = char(zeros(NBblock,madre.epsi_time_length));
madre.altimeter = char(zeros(NBblock*2,madre.alt_time_length));
madre.fsync_err = char(zeros(NBblock,madre.fsync_err_length));
madre.aux1_chksum = char(zeros(NBblock,madre.aux_chksum_length));
madre.epsi_chksum = char(zeros(NBblock,madre.map_chksum_length));

switch firmware_version
    case 'microsecond' % ALB: I added the musecond timestamp in third position. So the header is longer
        madre.epsi_mutime = char(zeros(NBblock,madre.epsi_time_length));
        EPSI.madre = struct(...
            'EpsiStamp',NaN(NBblock,1),...
            'TimeStamp',NaN(NBblock,1),...
            'muTimeStamp',NaN(NBblock,1),...
            'altimeter',NaN(NBblock,2),...
            'fsync_err',NaN(NBblock,1),...
            'Checksum_aux1',NaN(NBblock,1),...
            'Checksum_map',NaN(NBblock,1));
    otherwise
        EPSI.madre = struct(...
            'EpsiStamp',NaN(NBblock,1),...
            'TimeStamp',NaN(NBblock,1),...
            'altimeter',NaN(NBblock,2),...
            'fsync_err',NaN(NBblock,1),...
            'Checksum_aux1',NaN(NBblock,1),...
            'Checksum_map',NaN(NBblock,1));
end

if(isfield(EPSI,'header'))
    EPSI.madre.time = NaN(NBblock,1);
end

if is_aux1
    EPSI.aux1 = struct(...
        'Aux1Stamp',NaN(NBblock*aux1.nbsample,1),...
        'T_raw',NaN(NBblock*aux1.nbsample,1),...
        'C_raw',NaN(NBblock*aux1.nbsample,1),...
        'P_raw',NaN(NBblock*aux1.nbsample,1),...
        'PT_raw',NaN(NBblock*aux1.nbsample,1));
end

for cha=1:Meta_Data.PROCESS.nb_channels
    wh_channel=Meta_Data.PROCESS.channels{cha};
    EPSI.epsi.(wh_channel) = NaN(NBblock,epsi.nbsamples);
end
EPSI.epsi.EPSInbsample=NaN(NBblock,epsi.nbsamples);

% we are checking if the very last block is good too.
check_endstr=mod(ind_madre(end)+epsi.offset(end)+epsi.name_length+epsi.total_length ...
                                - numel(str),epsi.total_length);
if check_endstr==0
    nb_block=NBblock;
else
    nb_block=NBblock-1;
end
% still initializing
if is_aux1
    aux1.stamp = char(zeros(nb_block*aux1.nbsample,aux1.stamp_length));
    aux1.sbe = char(zeros(nb_block*aux1.nbsample,aux1.sbe_length));
end
epsi.raw = int32(zeros(nb_block,epsi.total_length));


% now lets begin  reading and splitting!!!!
for i=1:numel(indblock)
    % grab local time if STREAMING SITUATION;
    if(isfield(EPSI,'header'))
        if (isfield(EPSI.header,'offset_time'))
            system.time(i,1:10) = str(ind_madre(i)-(10:-1:1));
        end
    end
    % read items in the EPSI block Header
    madre.epsi_stamp(i,:) = str(indblock(i)+(1:madre.epsi_stamp_length)+madre.epsi_stamp_offset);
    madre.epsi_time(i,:) = str(indblock(i)+(1:madre.epsi_time_length)+madre.epsi_time_offset);
    madre.aux1_chksum(i,:) = str(indblock(i)+(1:madre.aux_chksum_length)+madre.aux_chksum_offset);
    madre.epsi_chksum(i,:) = str(indblock(i)+(1:madre.map_chksum_length)+madre.map_chksum_offset);
    for j=1:2
        madre.altimeter((i-1)*2+j,:) = str(indblock(i)+(1:madre.alt_time_length)+madre.alt_time_offset(j));
    end
    madre.fsync_err(i,:) = str(indblock(i)+(1:madre.fsync_err_length)+madre.fsync_err_offset);
    switch firmware_version
        case 'microsecond' % ALB: I added the musecond timestamp in third position. So the header is longer
            madre.epsi_mutime(i,:) = str(indblock(i)+(1:madre.epsi_time_length)+madre.epsi_mutime_offset);
    end
    % read AUX1 (SBE49) block 
    if is_aux1
        for j=1:aux1.nbsample
            aux1.stamp((i-1)*aux1.nbsample+j,:) = str(indblock(i)+(1:aux1.stamp_length)+aux1.stamp_offset(j));
            aux1.sbe((i-1)*aux1.nbsample+j,:) = str(indblock(i)+(1:aux1.sbe_length)+aux1.sbe_offset(j));
        end
    end
    % get the EPSI block
    epsi.raw(i,:) = int32(str(indblock(i)+epsi.offset(end)+epsi.name_length+(1:epsi.total_length)));
end
% done with split file
toc

%convert 3 bytes ADC samples into 24 bits counts. 
epsi.raw1 = epsi.raw(:,1:epsi.bytes_per_channel:end)*256^2+ ...
            epsi.raw(:,2:epsi.bytes_per_channel:end)*256+ ...
            epsi.raw(:,3:epsi.bytes_per_channel:end);

if(isfield(EPSI,'header'))
    switch Meta_Data.PROCESS.recording_mod
        case 'STREAMING'
            system.time(:,11) = newline;
            system.time = system.time';
            system_time = textscan(system.time(:),'%f');
            EPSI.madre.time = system_time{1}/100/24/3600+EPSI.header.offset_time;
        case 'SD'
            EPSI.madre.time=0;
    end
end

% converting Hex into decimal. Starts with the header.
try
    EPSI.madre.EpsiStamp = hex2dec(madre.epsi_stamp);
    EPSI.madre.TimeStamp = hex2dec(madre.epsi_time);
    EPSI.madre.altimeter = reshape(hex2dec(madre.altimeter),2,[])';
    EPSI.madre.fsync_err = hex2dec(madre.fsync_err);
    EPSI.madre.Checksum_aux1 = hex2dec(madre.aux1_chksum);
    EPSI.madre.Checksum_map = hex2dec(madre.epsi_chksum);
    switch firmware_version
        case 'microsecond' % ALB: I added the musecond timestamp in third position. So the header is longer
            EPSI.madre.muTimeStamp = hex2dec(madre.epsi_mutime);
    end
catch
%     EPSI.madre.EpsiStamp = hex2dec(madre.epsi_stamp);
%     EPSI.madre.TimeStamp = hex2dec(madre.epsi_time);
%     EPSI.madre.altimeter = reshape(hex2dec(madre.altimeter),2,[])';
%     EPSI.madre.fsync_err = hex2dec(madre.fsync_err);
%     EPSI.madre.Checksum_aux1 = hex2dec(madre.aux1_chksum);
%     EPSI.madre.Checksum_map = hex2dec(madre.epsi_chksum);
%     switch firmware_version
%         case 'microsecond' % ALB: I added the musecond timestamp in third position. So the header is longer
%             EPSI.madre.muTimeStamp = hex2dec(madre.epsi_mutime);
%     end
end
% issues with the SD write and some bytes are not hex. if issues we scan
% the whole sbe time series to find the bad bytes and then use the average 
% increment from with the previous samples;
% TO DO get rid of the nameam Tdiff over 10s.
if is_aux1
    try 
        EPSI.aux1.T_raw = hex2dec(aux1.sbe(:,1:6));
        EPSI.aux1.C_raw = hex2dec(aux1.sbe(:,(1:6)+6));
        EPSI.aux1.P_raw = hex2dec(aux1.sbe(:,(1:6)+12));
        EPSI.aux1.PT_raw = hex2dec(aux1.sbe(:,(1:4)+18));
        EPSI.aux1.Aux1Stamp =hex2dec(aux1.stamp);
    catch 
        disp('bug in SBE hex bytes')
        % ALB:San's trick to get the errors and replace the bad char by '0'
        ind_sbe = ( aux1.sbe >='0' & ...
                aux1.sbe <='9')| ...
              ( aux1.sbe >='a' & ...
                aux1.sbe <='f')| ...
              ( aux1.sbe >='A' & ...
                aux1.sbe <='F');
            
        ind_stamp = ( aux1.stamp >='0' & ...
                aux1.stamp <='9')| ...
              ( aux1.stamp >='a' & ...
                aux1.stamp <='f')| ...
              ( aux1.stamp >='A' & ...
                aux1.stamp <='F');
            % replace bad char with '0'
            aux1.stamp(~ind_stamp)='0';
            aux1.sbe(~ind_sbe)='0';
            EPSI.aux1.T_raw = hex2dec(aux1.sbe(:,1:6));
            EPSI.aux1.C_raw = hex2dec(aux1.sbe(:,(1:6)+6));
            EPSI.aux1.P_raw = hex2dec(aux1.sbe(:,(1:6)+12));
            EPSI.aux1.PT_raw = hex2dec(aux1.sbe(:,(1:4)+18));
            EPSI.aux1.Aux1Stamp =hex2dec(aux1.stamp);
            
%         for kk=1:size(aux1.stamp,1)
%             if mod(kk,5000)==0
%                 fprintf('%u over %u \n',kk,size(aux1.stamp,1));
%             end
%             try
%                 EPSI.aux1.T_raw(kk) = hex2dec(aux1.sbe(kk,1:6));
%                 EPSI.aux1.C_raw(kk) = hex2dec(aux1.sbe(kk,(1:6)+6));
%                 EPSI.aux1.P_raw(kk) = hex2dec(aux1.sbe(kk,(1:6)+12));
%                 EPSI.aux1.PT_raw(kk) = hex2dec(aux1.sbe(kk,(1:4)+18));
%                 EPSI.aux1.Aux1Stamp =hex2dec(aux1.stamp);
%             catch
% %                 try
% %                     EPSI.aux1.T_raw(kk) = EPSI.aux1.T_raw(kk-1)+ ...
% %                         nanmean(diff(EPSI.aux1.T_raw(kk-10:kk-1)));
% %                     EPSI.aux1.C_raw(kk) = EPSI.aux1.C_raw(kk-1)+ ...
% %                         nanmean(diff(EPSI.aux1.C_raw(kk-10:kk-1)));
% %                     EPSI.aux1.P_raw(kk) = EPSI.aux1.P_raw(kk-1)+ ...
% %                         nanmean(diff(EPSI.aux1.C_raw(kk-10:kk-1)));
% %                     EPSI.aux1.PT_raw(kk) =EPSI.aux1.PT_raw(kk-1)+ ...
% %                         nanmean(diff(EPSI.aux1.PT_raw(kk-10:kk-1)));
% %                     EPSI.aux1.Aux1Stamp(kk)=aux1.stamp(kk-1)+...
% %                         nanmean(diff(aux1.stamp(kk-10:kk-1)));
% %                 catch
% %                     EPSI.aux1.T_raw(kk) = 0;
% %                     EPSI.aux1.C_raw(kk) = 0;
% %                     EPSI.aux1.P_raw(kk) = 0;
% %                     EPSI.aux1.PT_raw(kk) =0;
% %                     EPSI.aux1.Aux1Stamp(kk)=0;
% %                 end
%                 
%             end
%         end
    end
    [EPSI.aux1.Aux1Stamp,ia0,~] =unique(EPSI.aux1.Aux1Stamp,'stable');
    
    %ALB reorder the stamps and samples because until now we kept the zeros
    % in the aux block
    [EPSI.aux1.Aux1Stamp,ia1]=sort(EPSI.aux1.Aux1Stamp);
    EPSI.aux1.T_raw  = EPSI.aux1.T_raw(ia0(ia1));
    EPSI.aux1.C_raw  = EPSI.aux1.C_raw(ia0(ia1));
    EPSI.aux1.P_raw  = EPSI.aux1.P_raw(ia0(ia1));
    EPSI.aux1.PT_raw = EPSI.aux1.PT_raw(ia0(ia1));
    
    EPSI = epsi_ascii_get_temperature(EPSI);
    EPSI = epsi_ascii_get_pressure(EPSI);
    EPSI = epsi_ascii_get_conductivity(EPSI);
    % remove bad records for aux1
    ind = EPSI.aux1.Aux1Stamp == 0 & EPSI.aux1.T_raw == 0 & EPSI.aux1.C_raw == 0 & EPSI.aux1.P_raw == 0;
    aux1_fields = fieldnames(EPSI.aux1);
    for i  = 1:numel(aux1_fields)
        EPSI.aux1.(aux1_fields{i})(ind) = NaN;
    end
end


% parsing the EPSI block data
for cha=1:Meta_Data.PROCESS.nb_channels
    wh_channel=Meta_Data.PROCESS.channels{cha};
    EPSI.epsi.([wh_channel '_count']) = epsi.raw1(:,cha:epsi.nchannels:end);
end

% input epsi sample stamp on each according to the sample sent via madre
% record
EPSI.epsi.EPSInbsample = repmat(1:epsi.nbsamples,[NBblock 1])+repmat(EPSI.madre.EpsiStamp,[1 epsi.nbsamples])-epsi.nbsamples;
if(isfield(EPSI,'header'))
    % delayed by 1 sample period assuming that it would take a bit of time
    % to transfer the data.
    switch Meta_Data.PROCESS.recording_mod
        case 'STREAMING'
            EPSI.epsi.time = (repmat(1:epsi.nbsamples,[NBblock 1])-epsi.nbsamples-1)*epsi.sample_period/24/3600 + repmat(EPSI.madre.time,[1 epsi.nbsamples]);
        case 'SD'
    end
end

% coeficient for Unipolar or bipolar ADC configuration and alos to convert
% accelerometer Voltage into Accelereation units (in g).
full_range = 2.5;
bit_counts = 24;
gain = 1;
acc_offset = 1.65;
acc_factor = 0.66;

for cha=1:Meta_Data.PROCESS.nb_channels
    wh_channel=Meta_Data.PROCESS.channels{cha};
    if ~strcmp(wh_channel,'c')
        switch Meta_Data.epsi.(wh_channel).ADCconf
            case {'Bipolar','bipolar'}
                EPSI.epsi.(wh_channel)=full_range/gain* ...
                    (double(EPSI.epsi.([wh_channel '_count']))/2.^(bit_counts-1)-1);
            case {'Unipolar','unipolar'}
                EPSI.epsi.(wh_channel)=full_range/gain* ...
                    double(EPSI.epsi.([wh_channel '_count']))/2.^(bit_counts);
                
        end
        
        switch wh_channel
            case 'a1'
                EPSI.epsi.a1 = (EPSI.epsi.a1-acc_offset)/acc_factor;
            case 'a2'
                EPSI.epsi.a2 = (EPSI.epsi.a2-acc_offset)/acc_factor;
            case 'a3'
                EPSI.epsi.a3 = (EPSI.epsi.a3-acc_offset)/acc_factor;
        end
    end
end


% grab all the epsi field names.
epsi_fields = fieldnames(EPSI.epsi);


% lay all records out straight instead of bunching them up with the MADRE
% records
for i  = 1:numel(epsi_fields)
    EPSI.epsi.(epsi_fields{i}) = reshape(EPSI.epsi.(epsi_fields{i})',[],1);
end

if(isfield(EPSI.epsi,'time') && ~isempty(EPSI.epsi.time)) && is_aux1
    EPSI.aux1.time = NaN(size(EPSI.aux1.Aux1Stamp));
    [ia, ib] = ismember(EPSI.aux1.Aux1Stamp,EPSI.epsi.EPSInbsample);
    EPSI.aux1.time(ia) = EPSI.epsi.time(ib(ib>0));
end
toc
end

function epsi = mod_combine_epsi(varargin)
% mod_combine_epsi - combines epsi data files in MATLAB format that was
% converted using mod_read_epsi_raw
%
% mod_combine_epsi(epsi1,epsi2,epsi3,...) returns a EPSI structure of variables described
% for MET data files
%
% Written 2018/10/15 - San Nguyen stn 004@ucsd.edu

if nargin < 1 
    epsi = [];
    return;
end

if nargin == 1
   epsi = varargin{1};
   if length(epsi) == 1
       return;
   end
   evalstr = 'epsi = mod_combine_epsi(';
   for i=1:(length(epsi)-1)
       evalstr = strcat(evalstr, 'epsi(', num2str(i), '),');
   end
   evalstr = strcat(evalstr, 'epsi(', num2str(length(epsi)), '));');
   eval(evalstr);
   return
end

epsi_fields = fieldnames(varargin{1});
for i = 2:nargin
    tmp_fields = fieldnames(varargin{i});
    for j = 1:numel(tmp_fields)
        if ~ismember(tmp_fields{j},epsi_fields)
            epsi_fields{end+1} = tmp_fields{j};
        end
    end
end

epsi_sub_fields = cell(size(epsi_fields));

for i = 1:numel(epsi_fields)
    epsi_sub_fields{i} = fieldnames(varargin{1}.(epsi_fields{i}));
    
    for j = 2:nargin
        tmp_fields = fieldnames(varargin{j}.(epsi_fields{i}));
        for k = 1:numel(tmp_fields)
            if ~ismember(tmp_fields{k},epsi_sub_fields{i})
                epsi_sub_fields{i}{end+1} = tmp_fields{k};
            end
        end
    end
end

for i=1:(length(epsi_fields))
    %header field
    if strcmpi(epsi_fields{i},'header')
        evalstr = strcat('epsi.', epsi_fields{i}, '= [');
        for j=1:(nargin-1)
            if ~isfield(varargin{j},(epsi_fields{i}))
                varargin{j}.(epsi_fields{i}) = NaN(size(varargin{j}.Time));
            end
            evalstr = strcat(evalstr, 'varargin{', num2str(j), '}.', epsi_fields{i}, ';');
        end
        if ~isfield(varargin{nargin},(epsi_fields{i}))
            varargin{nargin}.(epsi_fields{i}) = NaN(size(varargin{nargin}.Time));
        end
        evalstr = strcat(evalstr, 'varargin{', num2str(nargin), '}.', epsi_fields{i}, '];');
        eval(evalstr);
        continue;
    end
    % other fields
    for j=1:(length(epsi_sub_fields{i}))
        evalstr = strcat('epsi.',epsi_fields{i} ,'.', epsi_sub_fields{i}{j}, '= [');
        for k=1:(nargin-1)
            if ~isfield(varargin{k},epsi_fields{i})
                continue;
            end
            if ~isfield(varargin{k}.(epsi_fields{i}),(epsi_sub_fields{i}{j}))
                continue;
            end
            evalstr = strcat(evalstr, 'varargin{', num2str(k), '}.',epsi_fields{i} ,'.',epsi_sub_fields{i}{j}, ';');
        end
        if ~isfield(varargin{nargin},(epsi_fields{i}))
            evalstr = strcat(evalstr, '];');
        elseif ~isfield(varargin{nargin}.(epsi_fields{i}),(epsi_sub_fields{i}{j}))
            evalstr = strcat(evalstr, '];');
        else
            evalstr = strcat(evalstr, 'varargin{', num2str(nargin), '}.',epsi_fields{i} ,'.', epsi_sub_fields{i}{j}, '];');
        end
        eval(evalstr);
    end
end

% % sort out time
% [~, I] = sort(epsi.Time);
% 
% for i=1:(length(epsi_sub_fields))
%     if strcmpi(epsi_sub_fields{i},'README')
%         continue;
%     end
%     epsi.(epsi_sub_fields{i}) = epsi.(epsi_sub_fields{i})(I);
% end
% 
% %find unique time
% [~, I, ~] = unique(epsi.Time);
% 
% for i=1:(length(epsi_sub_fields))
%     if strcmpi(epsi_sub_fields{i},'README')
%         continue;
%     end
%     epsi.(epsi_sub_fields{i}) = epsi.(epsi_sub_fields{i})(I);
% end

end

%  parse all the lines in the header of the file
function EPSI = epsi_ascii_parseheader(fid)
EPSI = [];
fgetl(fid);
s=fgetl(fid);
[v,val]=epsi_ascii_parseheadline(s);
if ~isempty(v)
    eval(['EPSI.header.' lower(v) '=' val ';']);
end
s=fgetl(fid);
if(~strncmp(s,'%*****START_FCTD',16))
    return;
end

s=fgetl(fid);
while ~strncmp(s,'%*****END_FCTD',14) && ~feof(fid)
    [v,val]=epsi_ascii_parseheadline(s);
    if ~isempty(v)
        try
            eval(['EPSI.header.' lower(v) '=' val ';']);
        catch obj
            if strncmp(v,'FCTD_VER',8)
                eval(['EPSI.header.' lower(v) '=''' val ''';']);
            else
                %                 disp(obj.message);
                %                 disp(['Error occured in string: ' s]);
            end
            
        end
    end
    s=fgetl(fid);
    %     strncmp(s,'%*****END_FCTD',14);
end
return;
end

%  parse each line in the header to detect comments
function [v,val]=epsi_ascii_parseheadline(s)
if(isempty(s))
    v = [];
    val = [];
    return;
end
if s(1)~='%'
    
    i = strfind(s,'=');
    v=s(1:i-1);
    val = s(i+1:end);
else
    v=[];
    val=[];
end

return;
end


function corrected_time = epsi_ascii_correct_negative_time(time)
corrected_time = time;
neg_time = time(time<0);
corrected_time(time<=0) = 2^64 + neg_time;
end


%  reads and apply calibration to the temperature data
function EPSI = epsi_ascii_get_temperature(EPSI)

a0 = EPSI.header.ta0;
a1 = EPSI.header.ta1;
a2 = EPSI.header.ta2;
a3 = EPSI.header.ta3;

mv = (EPSI.aux1.T_raw-524288)/1.6e7;
r = (mv*2.295e10 + 9.216e8)./(6.144e4-mv*5.3e5);
EPSI.aux1.T = a0+a1*log(r)+a2*log(r).^2+a3*log(r).^3;
EPSI.aux1.T = 1./EPSI.aux1.T - 273.15;
return;
end

%  reads and apply calibration to the conductivity data
function EPSI = epsi_ascii_get_conductivity(EPSI)
try 
g = EPSI.header.g;
h = EPSI.header.h;
i = EPSI.header.i;
j = EPSI.header.j;
tcor = EPSI.header.tcor;
pcor = EPSI.header.pcor;
catch
g = EPSI.header.cg;
h = EPSI.header.ch;
i = EPSI.header.ci;
j = EPSI.header.cj;
tcor = EPSI.header.ctcor;
pcor = EPSI.header.cpcor;
end

f = EPSI.aux1.C_raw/256/1000;

EPSI.aux1.C = (g+h*f.^2+i*f.^3+j*f.^4)./(1+tcor*EPSI.aux1.T+pcor*EPSI.aux1.P);

return;
end

%  reads and apply calibration to the pressure data
function EPSI = epsi_ascii_get_pressure(EPSI)
% ALB 04112019 Changed EPSI.header.SBEcal. to EPSI.header.
pa0 = EPSI.header.pa0;
pa1 = EPSI.header.pa1;
pa2 = EPSI.header.pa2;
ptempa0 = EPSI.header.ptempa0;
ptempa1 = EPSI.header.ptempa1;
ptempa2 = EPSI.header.ptempa2;
ptca0 = EPSI.header.ptca0;
ptca1 = EPSI.header.ptca1;
ptca2 = EPSI.header.ptca2;
ptcb0 = EPSI.header.ptcb0;
ptcb1 = EPSI.header.ptcb1;
ptcb2 = EPSI.header.ptcb2;


y = EPSI.aux1.PT_raw/13107;

t = ptempa0+ptempa1*y+ptempa2*y.^2;
x = EPSI.aux1.P_raw-ptca0-ptca1*t-ptca2*t.^2;
n = x*ptcb0./(ptcb0+ptcb1*t+ptcb2*t.^2);

EPSI.aux1.P = (pa0+pa1*n+pa2*n.^2-14.7)*0.689476;

return;
end