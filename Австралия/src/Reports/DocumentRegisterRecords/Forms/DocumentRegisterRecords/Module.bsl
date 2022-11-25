
#Region GeneralPurposeProceduresAndFunctions

&AtServer
// The procedure generates a report on server.
//
Procedure GenerateReport()
	
	ObjectReport = FormAttributeToValue("Report");
	SpreadsheetDocument = ObjectReport.GenerateReport();
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Parameters.Property("Document") Then
		Report.Document = Parameters.Document;
	EndIf; 
	
	Report.SubordinateDocumentsStructureGrouping = Enums.SubordinateDocumentsStructureGrouping.Horizontal;
	GenerateReport();
	
EndProcedure

&AtClient
// Procedure - "Generate" button clicking handler
//
Procedure MakeExecute()
	
	GenerateReport();
	
EndProcedure

#EndRegion
