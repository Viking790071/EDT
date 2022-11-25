#Region EventHandlers

&AtClient
Procedure OnOpen(Cancel)
	Cancel = True;
	ShowMessageBox(, NStr("ru='Обработка не предназначена для непосредственного использования.'; en = 'The data processor is not intended for direct usage.'; pl = 'Opracowanie nie jest przeznaczone do bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanıma yönelik değil.';it = 'L''elaboratore dati non è inteso per un uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'"));
EndProcedure

#EndRegion