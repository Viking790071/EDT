#Region Public

Procedure AttachPrintFormsToObject(SpreadsheetDocuments, ObjectToAttach, FormUUID) Export
	
	If FilesOperationsServerCallDrive.GetArchivePrintFormsOption() Then
		
		WrittenObjects = FilesOperationsServerCallDrive.AttachPrintFormsToObject(SpreadsheetDocuments,
			ObjectToAttach,
			FormUUID);
		
		If WrittenObjects.Count() > 0 Then
			NotifyChanged(TypeOf(WrittenObjects[0]));
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion