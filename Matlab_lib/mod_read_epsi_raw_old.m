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

% check if it is a single file or a directory and a set of files
if ischar(filename) % dir or file
    switch exist(filename,'file')
        case 2 % if it is a file
            fid = fopen(filename,'r');
            epsi = mod_read_epsi_raw(fid);
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
                    epsi{i} = mod_read_epsi_raw(fullfile(filename,my_epsi_file(i).name));
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
        epsi{i} = mod_read_epsi_raw(filename{i});
    end
    % combine all files into one epsi structure
    epsi = mod_combine_epsi(epsi{:});
else
    
    if (filename<1)
        error('MATLAB:mod_read_epsi_raw:wrongFID','FID is invalid');
    end
    
    epsi = mod_read_epsi_raw_file(filename);
    
    return
end

end

% reading epsi files through FID
function EPSI = mod_read_epsi_raw_file(fid)
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
end


fseek(fid,0,1);
fsize = ftell(fid);
frewind(fid);

str = fread(fid,'*char')';



%%
%clc;
% tic
ind_madre = strfind(str,'$MADRE');
ind_aux1 = strfind(str,'$AUX1');
toc
if(isfield(EPSI,'header'))
    system.time = char(zeros(numel(ind_madre),11));
end
madre.offset = 0;
madre.name_length = 6;
madre.epsi_stamp_offset = -1+madre.name_length;
madre.epsi_time_offset = 8+madre.name_length;
madre.alt_time_offset = [17,21]+madre.name_length;
madre.fsync_err_offset = 35+madre.name_length;
madre.aux_chksum_offset = 26+madre.name_length;
madre.map_chksum_offset = 44+madre.name_length;

madre.epsi_stamp_length = 8;
madre.epsi_time_length = 8;
madre.alt_time_length = 4;
madre.aux_chksum_length = 8;
madre.map_chksum_length = 8;
madre.fsync_err_length = 8;

madre.epsi_stamp = char(zeros(numel(ind_madre),madre.epsi_stamp_length));
madre.epsi_time = char(zeros(numel(ind_madre),madre.epsi_time_length));
madre.altimeter = char(zeros(numel(ind_madre)*2,madre.alt_time_length));
madre.fsync_err = char(zeros(numel(ind_madre),madre.fsync_err_length));
madre.aux1_chksum = char(zeros(numel(ind_madre),madre.aux_chksum_length));
madre.epsi_chksum = char(zeros(numel(ind_madre),madre.map_chksum_length));

if (isempty(ind_aux1))
    aux1.offset = nan();
else
    aux1.offset = madre.offset+madre.name_length+madre.epsi_stamp_length+1+madre.epsi_time_length+1+madre.alt_time_length*2+1+madre.aux_chksum_length+1+madre.fsync_err_length+1+madre.map_chksum_length+2-1;
end%60; %madre.offset+madre.name_length+madre.epsi_stamp_length+1+madre.epsi_time_length+1+madre.alt_time_length*4+2+madre.aux_chksum_length+1+madre.map_chksum_length+2-1;
aux1.name_length = 5;
aux1.stamp_offset = (0:8)*33+aux1.name_length+aux1.offset;
aux1.sbe_offset = (0:8)*33+9+aux1.name_length+aux1.offset;

aux1.stamp_length = 8;
aux1.sbe_length = 22;

aux1.stamp = char(zeros(numel(ind_madre)*9,aux1.stamp_length));
aux1.sbe = char(zeros(numel(ind_madre)*9,aux1.sbe_length));

if isnan(aux1.offset)
    epsi.offset = madre.offset+madre.name_length+madre.epsi_stamp_length+1+madre.epsi_time_length+1+madre.alt_time_length*2+1+madre.aux_chksum_length+1+madre.fsync_err_length+1+madre.map_chksum_length+2-1;
else
    epsi.offset = aux1.offset+aux1.name_length+(aux1.stamp_length+1+aux1.sbe_length+2)*9+1;
end
epsi.name_length = 5;
epsi.nblocks = 160;
epsi.nchannels = Meta_Data.PROCESS.nb_channels;
epsi.sample_freq = 320;
epsi.sample_period = 1/epsi.sample_freq;
epsi.bytes_per_channel = 3;
epsi.total_length = epsi.nblocks*epsi.nchannels*epsi.bytes_per_channel;
epsi.raw = int32(zeros(numel(ind_madre),epsi.total_length));

EPSI.madre = struct(...
    'EpsiStamp',NaN(numel(ind_madre),1),...
    'TimeStamp',NaN(numel(ind_madre),1),...
    'altimeter',NaN(numel(ind_madre),2),...
    'fsync_err',NaN(numel(ind_madre),1),...
    'Checksum_aux1',NaN(numel(ind_madre),1),...
    'Checksum_map',NaN(numel(ind_madre),1));
if(isfield(EPSI,'header'))
    EPSI.madre.time = NaN(numel(ind_madre),1);
end
EPSI.aux1 = struct(...
    'Aux1Stamp',NaN(numel(ind_madre),9),...
    'T_raw',NaN(numel(ind_madre),9),...
    'C_raw',NaN(numel(ind_madre),9),...
    'P_raw',NaN(numel(ind_madre),9),...
    'PT_raw',NaN(numel(ind_madre),9));
EPSI.epsi = struct(...
    'EPSInbsample',NaN(numel(ind_madre),160),...
    't1',NaN(numel(ind_madre),160),...
    't2',NaN(numel(ind_madre),160),...
    's1',NaN(numel(ind_madre),160),...
    's2',NaN(numel(ind_madre),160),...
    'a1',NaN(numel(ind_madre),160),...
    'a2',NaN(numel(ind_madre),160),...
    'a3',NaN(numel(ind_madre),160));


%%
% tic
for i=1:numel(ind_madre)
    if(isfield(EPSI,'header'))
        system.time(i,1:10) = str(ind_madre(i)-(10:-1:1));
    end
    madre.epsi_stamp(i,:) = str(ind_madre(i)+(1:madre.epsi_stamp_length)+madre.epsi_stamp_offset);
    madre.epsi_time(i,:) = str(ind_madre(i)+(1:madre.epsi_time_length)+madre.epsi_time_offset);
    madre.aux1_chksum(i,:) = str(ind_madre(i)+(1:madre.aux_chksum_length)+madre.aux_chksum_offset);
    madre.epsi_chksum(i,:) = str(ind_madre(i)+(1:madre.map_chksum_length)+madre.map_chksum_offset);
    for j=1:2
        madre.altimeter((i-1)*2+j,:) = str(ind_madre(i)+(1:madre.alt_time_length)+madre.alt_time_offset(j));
    end
    madre.fsync_err(i,:) = str(ind_madre(i)+(1:madre.fsync_err_length)+madre.fsync_err_offset);
    if ~isnan(aux1.offset)
        for j=1:9
            aux1.stamp((i-1)*9+j,:) = str(ind_madre(i)+(1:aux1.stamp_length)+aux1.stamp_offset(j));
            aux1.sbe((i-1)*9+j,:) = str(ind_madre(i)+(1:aux1.sbe_length)+aux1.sbe_offset(j));
        end
    end
    epsi.raw(i,:) = int32(str(ind_madre(i)+epsi.offset+epsi.name_length+(1:epsi.total_length)));
    
    
end
toc
epsi.raw1 = epsi.raw(:,1:3:end)*256^2+epsi.raw(:,2:3:end)*256+epsi.raw(:,3:3:end);
if(isfield(EPSI,'header'))
    system.time(:,11) = newline;
    
    system.time = system.time';
    system_time = textscan(system.time(:),'%f');
    
    EPSI.madre.time = system_time{1}/100/24/3600+EPSI.header.offset_time;
end
EPSI.madre.EpsiStamp = hex2dec(madre.epsi_stamp);
EPSI.madre.TimeStamp = hex2dec(madre.epsi_time);
EPSI.madre.altimeter = reshape(hex2dec(madre.altimeter),2,[])';
EPSI.madre.fsync_err = hex2dec(madre.fsync_err);
EPSI.madre.Checksum_aux1 = hex2dec(madre.aux1_chksum);
EPSI.madre.Checksum_map = hex2dec(madre.epsi_chksum);

if ~isnan(aux1.offset)
    EPSI.aux1.Aux1Stamp = hex2dec(aux1.stamp);
    EPSI.aux1.T_raw = hex2dec(aux1.sbe(:,1:6));
    EPSI.aux1.C_raw = hex2dec(aux1.sbe(:,(1:6)+6));
    EPSI.aux1.P_raw = hex2dec(aux1.sbe(:,(1:6)+12));
    EPSI.aux1.PT_raw = hex2dec(aux1.sbe(:,(1:4)+18));
end

if(isfield(EPSI,'header'))
    EPSI = epsi_ascii_get_tempurature(EPSI);
    EPSI = epsi_ascii_get_pressure(EPSI);
    EPSI = epsi_ascii_get_conductivity(EPSI);
end

if ~isnan(aux1.offset)
    % remove bad records for aux1
    ind = EPSI.aux1.Aux1Stamp == 0 & EPSI.aux1.T_raw == 0 & EPSI.aux1.C_raw == 0 & EPSI.aux1.P_raw == 0;
    aux1_fields = fieldnames(EPSI.aux1);
    for i  = 1:numel(aux1_fields)
        EPSI.aux1.(aux1_fields{i})(ind) = NaN;
    end
end

EPSI.epsi.t1_count = epsi.raw1(:,1:epsi.nchannels:end);
EPSI.epsi.t2_count = epsi.raw1(:,2:epsi.nchannels:end);
EPSI.epsi.s1_count = epsi.raw1(:,3:epsi.nchannels:end);
EPSI.epsi.s2_count = epsi.raw1(:,4:epsi.nchannels:end);

% work with various number of channels
if epsi.nchannels < 8
    if epsi.nchannels > 4
        EPSI.epsi.a1_count = epsi.raw1(:,5:epsi.nchannels:end);
    end
    if epsi.nchannels > 5
        EPSI.epsi.a2_count = epsi.raw1(:,6:epsi.nchannels:end);
    end
    if epsi.nchannels > 6
        EPSI.epsi.a3_count = epsi.raw1(:,7:epsi.nchannels:end);
    end
else
    EPSI.epsi.ramp_count = epsi.raw1(:,5:epsi.nchannels:end);
    EPSI.epsi.a1_count = epsi.raw1(:,6:epsi.nchannels:end);
    EPSI.epsi.a2_count = epsi.raw1(:,7:epsi.nchannels:end);
    EPSI.epsi.a3_count = epsi.raw1(:,8:epsi.nchannels:end);
end
% input epsi sample stamp on each according to the sample sent via madre
% record
EPSI.epsi.EPSInbsample = repmat(1:epsi.nblocks,[numel(ind_madre) 1])+repmat(EPSI.madre.EpsiStamp,[1 epsi.nblocks])-epsi.nblocks;
if(isfield(EPSI,'header'))
    % delayed by 1 sample period assuming that it would take a bit of time
    % to transfer the data.
    EPSI.epsi.time = (repmat(1:epsi.nblocks,[numel(ind_madre) 1])-epsi.nblocks-1)*epsi.sample_period/24/3600 + repmat(EPSI.madre.time,[1 epsi.nblocks]);
end
full_range = 2.5;
bit_counts = 24;
gain = 1;
acc_offset = 1.65;
acc_factor = 0.66;
% % bipolar
% EPSI.epsi.t1=full_range/gain* ...
%     (double(EPSI.epsi.t1_count)/2.^(bit_counts-1)-1);
% EPSI.epsi.t2=full_range/gain* ...
%     (double(EPSI.epsi.t2_count)/2.^(bit_counts-1)-1);
% EPSI.epsi.s1=full_range/gain* ...
%     (double(EPSI.epsi.s1_count)/2.^(bit_counts-1)-1);
% EPSI.epsi.s2=full_range/gain* ...
%     (double(EPSI.epsi.s2_count)/2.^(bit_counts-1)-1);
% EPSI.epsi.a1 = full_range/gain* ...
%     double(EPSI.epsi.a1_count)/2.^(bit_counts);
% EPSI.epsi.a2 = full_range/gain* ...
%     double(EPSI.epsi.a2_count)/2.^(bit_counts);
% EPSI.epsi.a3 = full_range/gain* ...
%     double(EPSI.epsi.a3_count)/2.^(bit_counts);

% unipolar
 
EPSI.epsi.t1=full_range/gain* ...
    double(EPSI.epsi.t1_count)/2.^(bit_counts);
EPSI.epsi.t2=full_range/gain* ...
    double(EPSI.epsi.t2_count)/2.^bit_counts;
EPSI.epsi.s1=full_range/gain* ...
    double(EPSI.epsi.s1_count)/2.^(bit_counts);
EPSI.epsi.s2=full_range/gain* ...
    double(EPSI.epsi.s2_count)/2.^(bit_counts);
EPSI.epsi.a1 = full_range/gain* ...
    double(EPSI.epsi.a1_count)/2.^(bit_counts);
EPSI.epsi.a2 = full_range/gain* ...
    double(EPSI.epsi.a2_count)/2.^(bit_counts);
EPSI.epsi.a3 = full_range/gain* ...
    double(EPSI.epsi.a3_count)/2.^(bit_counts);


EPSI.epsi.a1 = (EPSI.epsi.a1-acc_offset)/acc_factor;
EPSI.epsi.a2 = (EPSI.epsi.a2-acc_offset)/acc_factor;
EPSI.epsi.a3 = (EPSI.epsi.a3-acc_offset)/acc_factor;

epsi_fields = fieldnames(EPSI.epsi);


% lay all records out straight instead of bunching them up with the MADRE
% records
for i  = 1:numel(epsi_fields)
    EPSI.epsi.(epsi_fields{i}) = reshape(EPSI.epsi.(epsi_fields{i})',[],1);
end

if(isfield(EPSI.epsi,'time') && ~isempty(EPSI.epsi.time)) && ~isnan(aux1.offset)
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
function EPSI = epsi_ascii_get_tempurature(EPSI)

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

g = EPSI.header.cg;
h = EPSI.header.ch;
i = EPSI.header.ci;
j = EPSI.header.cj;
tcor = EPSI.header.ctcor;
pcor = EPSI.header.cpcor;

f = EPSI.aux1.C_raw/256/1000;

EPSI.aux1.C = (g+h*f.^2+i*f.^3+j*f.^4)./(1+tcor*EPSI.aux1.T+pcor*EPSI.aux1.P);

return;
end

%  reads and apply calibration to the pressure data
function EPSI = epsi_ascii_get_pressure(EPSI)

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