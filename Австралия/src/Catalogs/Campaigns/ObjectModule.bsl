#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each ActivityLine In Activities Do
		
		SearchStructure = New Structure("Activity", ActivityLine.Activity);
		
		If Activities.FindRows(SearchStructure).Count() > 1 Then
			
			MessageText = NStr("en = 'There are duplicates in Activities table.'; ru = 'В таблице Активности есть повторяющиеся строки.';pl = 'W tabeli Rodzaj działalności znajdują się duplikaty.';es_ES = 'Hay duplicados en la Tabla de actividades.';es_CO = 'Hay duplicados en la Tabla de actividades.';tr = 'Faaliyet tablosunda yinelenenler var.';it = 'Ci sono duplicati nella tabella Attività.';de = 'Es gibt Duplikate in der Tabelle Aktivitäten.'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Activities",
				ActivityLine.LineNumber,
				"Activity",
				Cancel);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf