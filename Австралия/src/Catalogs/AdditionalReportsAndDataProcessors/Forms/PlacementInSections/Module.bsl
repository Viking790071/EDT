
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Filling the table of available sections.
	
	UsedSections = New Array;
	If Parameters.DataProcessorKind = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor Then
		UsedSections = AdditionalReportsAndDataProcessors.AdditionalDataProcessorSections();
	Else
		UsedSections = AdditionalReportsAndDataProcessors.AdditionalReportSections();
	EndIf;
	
	Desktop = AdditionalReportsAndDataProcessorsClientServer.DesktopID();
	
	For Each Section In UsedSections Do
		NewRow = Sections.Add();
		If Section = Desktop Then
			NewRow.Section = Catalogs.MetadataObjectIDs.EmptyRef();
		Else
			NewRow.Section = Common.MetadataObjectID(Section);
		EndIf;
		NewRow.Presentation = AdditionalReportsAndDataProcessors.SectionPresentation(NewRow.Section);
	EndDo;
	
	Sections.Sort("Presentation Asc");
	
	// Enabling sections
	
	For Each ListItem In Parameters.Sections Do
		FoundRow = Sections.FindRows(New Structure("Section", ListItem.Value));
		If FoundRow.Count() = 1 Then
			FoundRow[0].Used = True;
		EndIf;
	EndDo;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	SelectionResult = New ValueList;
	
	For Each ItemSection In Sections Do
		If ItemSection.Used Then
			SelectionResult.Add(ItemSection.Section);
		EndIf;
	EndDo;
	
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion
