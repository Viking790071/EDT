
#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DeleteRecords(Command)
	
	QuestionText = NStr("ru = 'Удаление записей по версиям объектов может привести к невозможности 
		|выполнения анализа всей цепочки изменений этих объектов. Продолжить?'; 
		|en = 'Deletion of object version records may prevent
		|the analysis of the whole chain of the object changes. Continue?'; 
		|pl = 'Usuwanie wpisów według wersji obiektu może spowodować uniemożliwienie 
		| przeprowadzenia analizy całego łańcucha zmian tych obiektów. Chcesz kontynuować?';
		|es_ES = 'Eliminación de los registros de la versión del objeto puede causar la incapacidad de 
		|realizar el análisis de toda la cadena de cambios del objeto. ¿Continuar?';
		|es_CO = 'Eliminación de los registros de la versión del objeto puede causar la incapacidad de 
		|realizar el análisis de toda la cadena de cambios del objeto. ¿Continuar?';
		|tr = 'Nesne sürüm kayıtlarının silinmesi, tüm nesne değişim zincirinin analizini 
		|gerçekleştirememeye neden olabilir. Devam et?';
		|it = 'La cancellazione dei record di versione dell''oggetto può impedire
		|l''analisi dell''intera catena delle modifiche dell''oggetto. Continuare?';
		|de = 'Das Löschen von Datensätzen nach Versionen von Objekten kann dazu führen,
		|dass die gesamte Kette der Änderungen an diesen Objekten nicht analysiert werden kann. Fortsetzen?'");
		
	NotifyDescription = New NotifyDescription("DeleteRecordsCompletion", ThisObject, Items.List.SelectedRows);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("ru = 'Предупреждение'; en = 'Warning'; pl = 'Ostrzeżenie';es_ES = 'Aviso';es_CO = 'Aviso';tr = 'Uyarı';it = 'Attenzione';de = 'Warnung'"));
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure DeleteRecordsCompletion(QuestionResult, RecordList) Export
	If QuestionResult = DialogReturnCode.Yes Then
		DeleteVersionsFromRegister(RecordList);
	EndIf;
EndProcedure

&AtServer
Procedure DeleteVersionsFromRegister(Val RecordList)
	
	For Each RecordKey In RecordList Do
		RecordSet = InformationRegisters.ObjectsVersions.CreateRecordSet();
		
		RecordSet.Filter.Object.Value = RecordKey.Object;
		RecordSet.Filter.Object.ComparisonType = ComparisonType.Equal;
		RecordSet.Filter.Object.Use = True;
		
		RecordSet.Filter.VersionNumber.Value = RecordKey.VersionNumber;
		RecordSet.Filter.VersionNumber.ComparisonType = ComparisonType.Equal;
		RecordSet.Filter.VersionNumber.Use = True;
		
		RecordSet.Write(True);
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
