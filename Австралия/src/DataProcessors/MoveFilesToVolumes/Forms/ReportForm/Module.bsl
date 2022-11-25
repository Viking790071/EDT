
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Explanation = Parameters.Explanation;
	
	SpreadsheetDoc = New SpreadsheetDocument;
	TabTemplate = DataProcessors.MoveFilesToVolumes.GetTemplate("ReportTemplate");
	
	AreaHeader = TabTemplate.GetArea("Title");
	AreaHeader.Parameters.Details = NStr("ru = 'Файлы с ошибками:'; en = 'Files with errors:'; pl = 'Pliki z błędami:';es_ES = 'Archivos con errores:';es_CO = 'Archivos con errores:';tr = 'Hatalı dosyalar:';it = 'I file con errori:';de = 'Dateien mit Fehlern:'");
	SpreadsheetDoc.Put(AreaHeader);
	
	AreaRow = TabTemplate.GetArea("Row");
	
	For Each Selection In Parameters.FilesArrayWithErrors Do
		AreaRow.Parameters.Name = Selection.FileName;
		AreaRow.Parameters.Version = Selection.Version;
		AreaRow.Parameters.Error = Selection.Error;
		SpreadsheetDoc.Put(AreaRow);
	EndDo;
	
	Report.Put(SpreadsheetDoc);
	
EndProcedure

#EndRegion
