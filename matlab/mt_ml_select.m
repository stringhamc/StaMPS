function []=mt_ml_select(coh_thresh,image_fraction,weed_zero_elevation)
%MT_ML_SELECT small baseline multilooked select
%  []=mt_ml_select(coh_thresh,image_fraction,weed_zero_elevation)
%
%   Andy Hooper, July 2006
%
%   =============================================================
%   10/2008 AH: Generalised for different looks and single master
%   05/2009 AH: Drop pixels with duplicate lon/lat coordinates
%   08/2009 AH: Multilook lon/lat as read in to save memory 
%   08/2009 AH: Allow single master series  
%   03/2011 AH: Compatibility changes for matlab R2010b
%   =============================================================

if nargin<1
   coh_thresh=0.25;
end

if nargin<2
   image_fraction=0.3;
end

if nargin<3
    weed_zero_elevation='n';
end

phname=['pscands.1.ph'];            % for each PS candidate, a float complex value for each ifg
ijname=['pscands.1.ij'];            % ID# Azimuth# Range# 1 line per PS candidate
bperpname=['bperp.1.in'];           % in meters 1 line per slave image
dayname=['day.1.in'];               % YYYYMMDD, 1 line per slave image
ifgdayname=['ifgday.1.in'];         % YYYYMMDD YYYYMMDD, 1 line per ifg
masterdayname=['master_day.1.in'];  % YYYYMMDD
llname=['pscands.1.ll'];            % 2 float values (lon and lat) per PS candidate
daname=['pscands.1.da'];            % 1 float value per PS candidate
hgtname=['pscands.1.hgt'];          % 1 float value per PS candidate
laname=['look_angle.1.in'];         % grid of look angle values
lonname=['./lon.raw'];                % longitudes
latname=['./lat.raw'];                % latitudes
demradname=['./dem_radar_i.raw'];
headingname=['heading.1.in'];       % satellite heading
lambdaname=['lambda.1.in'];         % wavelength
calname=['calamp.out'];             % amplitide calibrations
widthname=['./width.txt'];            % width of interferograms
lenname=['./len.txt'];                % length of interferograms
looksname=['./looks.txt'];            % number of looks in range
arname=['./ar.txt'];                  % aspect ratio (pixel size in range/azimuth)


fprintf('Selecting multilooked pixels...\n')

PWD=pwd;
if PWD(end-13:end-9)=='INSAR'
    single_master_flag=1;
    masterdate=PWD(end-7:end);
else
    single_master_flag=0;
end

if ~exist(widthname,'file')
    widthname= ['.',widthname];
end
n_rg=load(widthname);

if ~exist(lenname,'file')
    lenname= ['.',lenname];
end
n_az=load(lenname);

if ~exist(looksname,'file')
    looksname= ['.',looksname];
end
if ~exist(looksname,'file')
    looks=4;
else
    looks=load(looksname);
end
cohname=['coh_',num2str(looks),'l'];
n_lrg=floor(n_rg/looks);

if ~exist(arname,'file')
    arname= ['.',arname];
end
if ~exist(arname,'file')
    ar=5;
else
    ar=load(arname);
end
n_laz=floor(n_az/looks/ar);

dirs=ls(['*/',cohname,'.raw']);
dirs=strread(dirs,'%s');
n_d=length(dirs);
ix=logical(zeros(floor(n_az/looks/ar),floor(n_rg/looks),n_d));
i1=0;
rubbish=char([27,91,48,48,109]);

for i=1:n_d
    if strfind(dirs{i},cohname)
        i1=i1+1;
        filename=dirs{i};
        coh_ix=strfind(filename,rubbish);
        if ~isempty(coh_ix)
            filename=filename(coh_ix(end-1)+5:coh_ix(end)-1); % drop extra stuff sometimes added to start and end
        end
        fid=fopen(filename);
        if fid<=0
           error([filename,' does not appear to exist'])
        end
        fprintf('   reading %s...\n',filename)
        coh=fread(fid,[n_lrg,inf],'float=>single');
        coh=coh';
        ix(:,:,i1)=coh>=coh_thresh;
        fclose(fid);
    end
end

ix=ix(:,:,1:i1);
ixsum=sum(ix,3);
ix=(ixsum>=i1*image_fraction);
[I,J]=find(ix);
ix=find(ix);
n_ps=length(ix);
ixsum=ixsum(ix);

azlooks=looks*ar;
[ny,nx]=size(coh);
lon=zeros(ny,nx,'single');
lat=zeros(ny,nx,'single');

if ~exist(lonname,'file')
    lonname= ['.',lonname];
end
lonmlname=[lonname(1:end-4),'_',num2str(looks),'l.raw'];

if exist(lonmlname,'file')
    fprintf('   reading %s...\n',lonmlname)
    fid=fopen(lonmlname);
    lon=fread(fid,[nx,ny],'float');
    lon=lon';
else
    fid=fopen(lonname);
    fprintf('   reading and multilooking %s...\n',lonname)
    for i=1:ny
      lon_slc=fread(fid,[n_rg,azlooks],'float=>single')';
      lon_ml=blkproc(lon_slc,[azlooks,looks],@(x) mean(x(:)));
      lon(i,:)=lon_ml(1:nx);
    end
    clear lon_slc
end
fclose(fid);
%lon=lon';
%lon=lon(round(looks*ar/2):looks*ar:end,round(looks/2):looks:end);
%lon=lon(1:n_laz,1:n_lrg);
lon=lon(ix);

if ~exist(latname,'file')
    latname= ['.',latname];
end
latmlname=[latname(1:end-4),'_',num2str(looks),'l.raw'];

if exist(latmlname,'file')
    fprintf('   reading %s...\n',latmlname)
    fid=fopen(latmlname);
    lat=fread(fid,[nx,ny],'float');
    lat=lat';
else
    fid=fopen(latname);
    fprintf('   reading and multilooking %s...\n',latname)
    for i=1:ny
      lat_slc=fread(fid,[n_rg,azlooks],'float=>single')';
      lat_ml=blkproc(lat_slc,[azlooks,looks],@(x) mean(x(:)));
      lat(i,:)=lat_ml(1:nx);
    end
    clear lat_slc
end
fclose(fid);
%lat=lat';
%lat=lat(round(looks*ar/2):looks*ar:end,round(looks/2):looks:end);
%lat=lat(1:n_laz,1:n_lrg);
lat=lat(ix);
lonlat=[lon,lat];
clear lon lat

%%%Drop pixels with duplicate lon/lat coords
[dummy,ui]=unique(lonlat,'rows');
ix_weed=[1:n_ps]';
dups=setxor(ui,ix_weed); % pixels with duplicate lon/lat
ix_weed=logical(ones(n_ps,1));
for i=1:length(dups)
    dups_ix=find(lonlat(:,1)==lonlat(dups(i),1)&lonlat(:,2)==lonlat(dups(i),2));
    [dummy,max_i]=max(ixsum(dups_ix));
    ix_weed(dups_ix(setxor(max_i,[1:length(dups_ix)])))=0; % drop dups with lowest consistency
end
if ~isempty(dups)
    ix=ix(ix_weed);
    n_ps=length(ix);
    lonlat=lonlat(ix_weed,:);
    fprintf('%d pixels with duplicate lon/lat dropped\n\n',length(dups)')
end


ll0=(max(lonlat)+min(lonlat))/2;
xy=llh2local(lonlat',ll0)*1000;
xy=xy';
sort_x=sortrows(xy,1);
sort_y=sortrows(xy,2);
n_pc=round(n_ps*0.001);
bl=mean(sort_x(1:n_pc,:)); % bottom left corner
tr=mean(sort_x(end-n_pc:end,:)); % top right corner
br=mean(sort_y(1:n_pc,:)); % bottom right  corner
tl=mean(sort_y(end-n_pc:end,:)); % top left corner

heading=load(headingname);
theta=(180-heading)*pi/180;
if theta>pi
    theta=theta-2*pi;
end

rotm=[cos(theta),sin(theta); -sin(theta),cos(theta)];
xy=xy';
xynew=rotm*xy; % rotate so that scene axes approx align with x=0 and y=0
if max(xynew(1,:))-min(xynew(1,:))<max(xy(1,:))-min(xy(1,:)) &...
   max(xynew(2,:))-min(xynew(2,:))<max(xy(2,:))-min(xy(2,:))
    xy=xynew; % check that rotation is an improvement
    disp(['Rotating by ',num2str(theta*180/pi),' degrees']);
end
        
xy=single(xy');
[dummy,sort_ix]=sortrows(xy,[2,1]); % sort in ascending y order
xy=xy(sort_ix,:);
xy=[[1:n_ps]',xy];
xy(:,2:3)=round(xy(:,2:3)*1000)/1000; % round to mm

lonlat=lonlat(sort_ix,:);
ix=ix(sort_ix);
ij=[[1:n_ps]',I(sort_ix)*looks*ar-round(looks*ar/2),J(sort_ix)*looks-round(looks/2)];


dirs=ls('-1',['*/cint.minrefdem_',num2str(looks),'l.raw']);
dirs=strread(dirs,'%s');
n_ifg=length(dirs);
ph=zeros(n_ps,n_ifg,'single');
day1_yyyymmdd=zeros(n_ifg,1);
day2_yyyymmdd=zeros(n_ifg,1);
i1=0;
for i=1:n_ifg
    if strfind(dirs{i},'minrefdem')
        i1=i1+1;
        filename=dirs{i};
        cint_ix=strfind(filename,rubbish);
        if ~isempty(cint_ix)
            filename=filename(cint_ix(end-1)+5:cint_ix(end)-1);
        end
        if single_master_flag==0
            day1_yyyymmdd(i1)=str2num(filename(1:8));
            day2_yyyymmdd(i1)=str2num(filename(10:17));
        else
            day1_yyyymmdd(i1)=str2num(masterdate);
            day2_yyyymmdd(i1)=str2num(filename(1:8));
        end
        fprintf('   reading %s\n',filename);
        ifg=readcpx(filename,n_lrg);
        ph(:,i1)=ifg(ix);
    end
end
n_ifg=i1;
ph=ph(:,1:i1);
day1_yyyymmdd=day1_yyyymmdd(1:i1);
day2_yyyymmdd=day2_yyyymmdd(1:i1);

nzix=sum(ph==0,2)==0;
ph=ph(nzix,:);
xy=xy(nzix,:);
ij=ij(nzix,:);
lonlat=lonlat(nzix,:);
ix=ix(nzix);
n_ps=size(ph,1);


year=floor(day1_yyyymmdd/10000);
month=floor((day1_yyyymmdd-year*10000)/100);
monthday=day1_yyyymmdd-year*10000-month*100;
ifgday(:,1)=datenum(year,month,monthday);
year=floor(day2_yyyymmdd/10000);
month=floor((day2_yyyymmdd-year*10000)/100);
monthday=day2_yyyymmdd-year*10000-month*100;
ifgday(:,2)=datenum(year,month,monthday);
[day,I,J]=unique(ifgday(:));
ifgday_ix=reshape(J,n_ifg,2);
master_day_yyyymmdd=load(masterdayname);
year=floor(master_day_yyyymmdd/10000);
month=floor((master_day_yyyymmdd-year*10000)/100);
monthday=master_day_yyyymmdd-year*10000-month*100;
master_day=datenum(year,month,monthday);
master_ix=sum(master_day>day)+1;
n_image=size(day,1);

psver=2;
save psver psver

if ~exist(demradname,'file')
    demradname=['.',demradname];
end
demmlname=[demradname(1:end-6),'_',num2str(looks),'l.raw'];

hgt=zeros(ny,nx,'single');

if exist(demmlname,'file')
    fprintf('   reading %s...\n',demmlname)
    fid=fopen(demmlname);
    hgt=fread(fid,[nx,ny],'float');
    hgt=hgt';
else
    fid=fopen(demradname);
    fprintf('   reading and multilooking %s...\n',demradname)
    for i=1:ny
      hgt_slc=fread(fid,[n_rg,azlooks],'float=>single')';
      hgt_ml=blkproc(hgt_slc,[azlooks,looks],@(x) mean(x(:)));
      hgt(i,:)=hgt_ml(1:nx);
    end
    clear hgt_slc
end
fclose(fid);
%fid=fopen(demradname);
%hgt=fread(fid,[n_rg,inf],'float');
%fclose(fid);
%hgt=hgt';
%hgt=hgt(round(looks*ar/2):looks*ar:end,round(looks/2):looks:end);
%hgt=hgt(1:n_laz,1:n_lrg);
hgt=hgt(ix);
if ~strcmpi(weed_zero_elevation,'n')
    nzix=hgt>0;
    hgt=hgt(nzix);
    ph=ph(nzix,:);
    xy=xy(nzix,:);
    ij=ij(nzix,:);
    lonlat=lonlat(nzix,:);
    ix=ix(nzix);
    n_ps=size(ph,1);
end

save('hgt2','hgt')

if single_master_flag~=0
    ph_rc=[ph(:,1:master_ix-1),zeros(size(ph,1),1),ph(:,master_ix:end)];
    n_ifg=n_ifg+1;
else
    ph_rc=ph;
end
save('rc2','ph_rc');

updir=0;
bperpdir=dir('bperp_*.1.in');
[gridX,gridY]=meshgrid(linspace(0,n_rg,50),linspace(0,n_az,50));

if isempty(bperpdir)
    bperpdir=dir('../bperp_*.1.in');
    updir=1;
end
bperp_mat=zeros(n_ps,n_image,'single');
for i=setdiff([1:n_image],master_ix);
    bperp_fname=['bperp_',datestr(day(i),'yyyymmdd'),'.1.in'];
    if updir==1
        bperp_fname=['../',bperp_fname];
    end
    bperp_grid=load(bperp_fname);
    bp0=bperp_grid(1:2:end);
    bp0=reshape(bp0,50,50)';
    bp1000=bperp_grid(2:2:end);
    bp1000=reshape(bp1000,50,50)';
    bp0_ps=griddata(gridX,gridY,bp0,ij(:,3),ij(:,2),'linear',{'QJ'});
    %bp1000_ps=griddata(gridX,gridY,bp1000,ij(:,3),ij(:,2),'linear',{'QJ'});
    %bperp_mat(:,i)=bp0_ps+(bp1000_ps-bp0_ps).*hgt/1000;
    bperp_mat(:,i)=bp0_ps;
end
%bperp_mat=[bperp_mat(:,1:master_ix-1),zeros(n_ps,1),bperp_mat(:,master_ix:end)]; % insert master-master bperp (zero)
%if single_master_flag==0
    bperp_mat=bperp_mat(:,ifgday_ix(:,2))-bperp_mat(:,ifgday_ix(:,1));
%end

bperp=mean(bperp_mat)';
save('bp2','bperp_mat')

if single_master_flag==0
    sb_parms_initial
else
    ps_parms_initial
end

if ~exist(headingname,'file')
    headingname= ['../',headingname];
end
heading=load(headingname);
if isempty(heading)
    error('heading.1.in is empty')
end
setparm('heading',heading,1);

if ~exist(lambdaname,'file')
    lambdaname= ['../',lambdaname];
end
lambda=load(lambdaname);
setparm('lambda',lambda,1);

save('ps2','ij','lonlat','xy','day','ifgday','ifgday_ix','bperp','master_day','master_ix','n_ifg','n_image','n_ps','ll0','master_ix');

setparm('weed_zero_elevation',weed_zero_elevation)
