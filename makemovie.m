% script to make movies of matlab IR camera data
% Written 3/13/2015
% modified 4/13/2015 (add conduction calculation)

%requires .mat and .bmp (box for ROI) files

function makemovie(filename, filemat, filebmp)
    %% load data and set ROI limits
    load(filemat);

    n = 2; % related to stencil size i.e. -n:n points
    m = 1; % order of interpolation

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
        cmdline = ['FrameData{1,i} = Frame' num2str(i) '(' ROIx ',' ROIy ');'];
        eval(cmdline);

        cmdline = ['FrameData{2,i} = Frame' num2str(i) '_DateTime;'];
        eval(cmdline);

        %clean up source data
        cmdline = ['clear Frame' num2str(i) ';'];
        eval(cmdline);

        cmdline = ['clear Frame' num2str(i) '_DateTime;'];
        eval(cmdline);
    end

    for i = 1:frame_max
        htxt2str = num2str(FrameData{2,i}(4:7));
        htxt2str = regexprep(htxt2str,'\s+',':');

        timestamplist{i} = htxt2str;
    end
    FrameData = [FrameData; timestamplist];

    %% apply filter, do conduction calculations

    kc = 16.3; %thermal conductivity of SS304 at 23C [W/m-K]
    th = 2.54e-5; %thickness of foil [m]
    
    dx = 0.011938/50; %one pixel is this many meters [px/m]
    % inside distance between the two electrodes is 0.47 inches.
    
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
        FrameData{1,i} = filter2(H,FrameData{1,i});
        Gmag = -4*del2(FrameData{1,i},dx) *th*kc;
%         Gmag = diff(FrameData{1,i},2);
%         Gmag = conv2(FrameData{1,i},L,'same');


        FrameData{1,i} = FrameData{1,i}(1+n:end-n,1+n:end-n);
        Cond{i} = Gmag(3+n:end-n-2,3+n:end-n-2);    
    end
    FrameData = [FrameData; Cond];
    clear Cond;

    %% find the max and min vals over the whole dataset
    temps = cell2mat(FrameData(1,:));
    TLimHi = max(max(temps));
    TLimLo = min(min(temps));

    cond = cell2mat(FrameData(4,:));
    CLimHi = max(max(cond));
    CLimLo = min(min(cond));

    clear temps;
    clear cond;

    %% make the movie
    figure('Position',[100 100 900 480]);

    subplot(1,2,1); %temperatures
    hplot1 = mesh(FrameData{1,1});
    % set(gcf,'Renderer','zbuffer');
    % set(gca,'nextplot','replacechildren');
    set(gca,'Zlim',[TLimLo TLimHi]);
    set(gca,'CLim',[TLimLo TLimHi]);
    colormap(gca,'Jet')

    subplot(1,2,2); %conduction
    hplot2 = surface(FrameData{4,1});
    shading flat;
    % set(gcf,'Renderer','zbuffer');
    % set(gca,'nextplot','replacechildren');


    set(gca,'Zlim',[CLimLo CLimHi]);
    set(gca,'CLim',[CLimLo CLimHi]);
    colormap(gca,'Jet')

    %timestamp string
    annotation('textbox',[0.02 0.9 0.1 0.1],'EdgeColor','none','String',filename,'interpreter','none');
    htxt1 = annotation('textbox',[0.9 0.9 0.1 0.1],'EdgeColor','none','String',{['Frame ' num2str(1)]});
    htxt2 = annotation('textbox',[0.02 0.87 0.1 0.1],'EdgeColor','none','String',{['Time ' timestamplist{1}]});

    %% run update depending on slider position

    %ui slider control
    h = uicontrol('style','slider','units','normalized','min',0,'max',frame_max,...
        'sliderstep',[slide_stepsize slide_stepsize],'position',[0.05 0.01 0.90 0.05]);
    addlistener(h,'ContinuousValueChange',@(hObject, event) makeplot(hObject,event,FrameData(1,:),timestamplist,hplot1,htxt1,htxt2));
    addlistener(h,'ContinuousValueChange',@(hObject, event) makeplot(hObject,event,FrameData(4,:),timestamplist,hplot2,htxt1,htxt2));

end