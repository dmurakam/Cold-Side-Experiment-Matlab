function makeplot(hObject,event,Data,Timestamp,hplot,htxt1,htxt2)
n = get(hObject,'Value');
n = ceil(n);

if n == 0; %slider bar remaps from 1 to end, excludes zero
    n = 1;
end

set(hplot,'Zdata',Data{n},'Cdata',Data{n});
set(htxt1,'String',{['Frame ' num2str(n)]});
set(htxt2,'String',{['Time ' Timestamp{n}]});
drawnow;
end
