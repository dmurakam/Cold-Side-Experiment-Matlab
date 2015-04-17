function makeplot(hObject,event,Data,Timestamp,hplot,htxt1,htxt2)
n = get(hObject,'Value');
n = round(n);
set(hplot,'Zdata',Data{n},'Cdata',Data{n});
set(htxt1,'String',{['Frame ' num2str(n)]});
set(htxt2,'String',{['Time ' Timestamp{n}]});
drawnow;
end
