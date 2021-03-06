% script to make movies of matlab IR camera data
% Written 3/13/2015
% modified 4/13/2015 (add conduction calculation)

%requires .mat and .bmp (box for ROI) files

function FrameData = makemovie(filename, filemat, filebmp, dx)
    %% load data and set ROI limits
    load(filemat);

    n = 4; % related to stencil size i.e. -n:n points
    m = 2; % order of interpolation
    
    FtoCconv = true; %convert data from F to K

    kc = 16.3; %thermal conductivity of SS304 at 23C [W/m-K]
    th = 2.54e-5; %thickness of foil [m]
    
    %ROI limits to crop to
    ROI = rgb2gray(importdata(filebmp)); 
    [ROIrow,ROIcol]=find(ROI);
    ROIx = [num2str(min(ROIcol)) ':' num2str(max(ROIcol))]; %xmin, xmax
    ROIy = [num2str(min(ROIrow)) ':' num2str(max(ROIrow))]; %ymin, ymax

    %% count the number of frames, create data structure
    frame_max = 1;
    while 1
        if exist(['Frame' num2str(frame_max+1)],'var') == 1 %if that frame exists
            frame_max = frame_max + 1;
        else
            break
        end
    end
    slide_stepsize = 1/frame_max;


    %% collapse all the data into a single cell array
    for i = 1:frame_max
        cmdline = ['FrameData.T{i} = Frame' num2str(i) '(' ROIy ',' ROIx ');'];
        eval(cmdline);

        cmdline = ['FrameData.Time{i} = Frame' num2str(i) '_DateTime;'];
        eval(cmdline);

        %clean up source data
        cmdline = ['clear Frame' num2str(i) ';'];
        eval(cmdline);

        cmdline = ['clear Frame' num2str(i) '_DateTime;'];
        eval(cmdline);
    end

    for i = 1:frame_max
        htxt2str = num2str(FrameData.Time{i}(4:7));
        htxt2str = regexprep(htxt2str,'\s+',':');

        timestamplist{i} = htxt2str;
        
        %convert from F to K
        if FtoCconv == true
            FrameData.T{i} = (FrameData.T{i} +459.67)*5/9;
        end
        
    end
    
    FrameData.TimeStampList = timestamplist;

    %% apply filter, do conduction calculations
    
    % savitzky-golay filter parameters
    %       h=sgsf_2d(x,y,px,py,flag_coupling)
    %       x    = x data point, e.g., -3:3
    %       y    = y data point, e.g., -2:2 
    %       px    =x polynomial order       default=1              
    %       py    =y polynomial order       default=1
    %       flag_coupling  = with or without the consideration of the coupling terms, between x and y. default=0
    H = sgsf_2d(-n:n,-n:n,m,m,0); %2D Savitzsky Golay smoothing filter
%     L = fspecial('laplacian',0);
    
    for i = 1:frame_max
        FrameData.T{i} = filter2(H,FrameData.T{i});
        Gmag = 4*del2(FrameData.T{i},dx);
%         Gmag = diff(FrameData{1,i},2);
%         Gmag = conv2(FrameData{1,i},L,'same');

        %crop off the edges where the filter produces wonky data
        FrameData.T{i} = FrameData.T{i}(2+n:end-n-1,2+n:end-n-1);
        
        %conduction within the foil
        %conduction in [W/m^2] times cross sectional area (dx*th) divide
        %by surface normal area
        FrameData.Cond{i} = Gmag(2+n:end-n-1,2+n:end-n-1)*kc*th;     
        
        %radiative loss to surroundings, q_rad = e*sig*(T^4-Tamb^4)
        FrameData.Rad{i} = -0.95*5.67e-8*(FrameData.T{i}.^4-300^4);
        
        FrameData.Heat{i} = FrameData.Cond{i} + FrameData.Rad{i};
    end

    %% find the max and min vals over the whole dataset
    temp = cell2mat(FrameData.T(:));
    TLimHi = max(max(temp));
    TLimLo = min(min(temp));

    temp = cell2mat(FrameData.Heat(:));
    CLimHi = max(max(temp));
    CLimLo = min(min(temp));

    clear temps;
    clear heat;

    %% make the movie
    figure('Position',[100 100 900 480]);

    subplot(1,2,1); %temperatures
    hplot1 = surface(FrameData.T{1});
    % set(gcf,'Renderer','zbuffer');
    % set(gca,'nextplot','replacechildren');
    set(gca,'Zlim',[TLimLo TLimHi]);
    set(gca,'CLim',[TLimLo TLimHi]);
    colormap(gca,'Jet')
    title('Temperatures');

    subplot(1,2,2); %heat
    hplot2 = surface(FrameData.Cond{1});
    shading flat;
    % set(gcf,'Renderer','zbuffer');
    % set(gca,'nextplot','replacechildren');
    title('Conduction');


    set(gca,'Zlim',[CLimLo CLimHi]);
    set(gca,'CLim',[CLimLo CLimHi]);
    colormap(gca,'Jet')

    %timestamp string
    annotation('textbox',[0.02 0.9 0.1 0.1],'EdgeColor','none','String',[filename ' n-' num2str(n) ' m-' num2str(m)],'interpreter','none');   
    htxt1 = annotation('textbox',[0.9 0.9 0.1 0.1],'EdgeColor','none','String',{['Frame ' num2str(1)]});
    htxt2 = annotation('textbox',[0.02 0.87 0.1 0.1],'EdgeColor','none','String',{['Time ' FrameData.TimeStampList{1}]});

    %% run update depending on slider position

    %ui slider control
    h = uicontrol('style','slider','units','normalized','min',0,'max',frame_max,...
        'sliderstep',[slide_stepsize slide_stepsize],'position',[0.05 0.01 0.90 0.05]);
    addlistener(h,'ContinuousValueChange',@(hObject, event) makeplot(hObject,event,FrameData.T,FrameData.TimeStampList,hplot1,htxt1,htxt2));
    addlistener(h,'ContinuousValueChange',@(hObject, event) makeplot(hObject,event,FrameData.Cond,FrameData.TimeStampList,hplot2,htxt1,htxt2));

end
