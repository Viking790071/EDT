#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	ExportingHSCodeChoiceListFilling()
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandler

&AtClient
Procedure CodeOnChange(Item)
	
	DafaultExportingHSCode = DafaultExportingHSCode();
	
	If IsBlankString(Object.ExportingHSCode) Then
		
		Object.ExportingHSCode = DafaultExportingHSCode;
		
	EndIf;
	
	ExportingHSCodeChoiceListFilling(DafaultExportingHSCode);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtClient
Function DafaultExportingHSCode()
	
	Return Left(TrimL(Object.Code), 8);
	
EndFunction

&AtClient
Procedure ExportingHSCodeChoiceListFilling(DafaultExportingHSCode = Undefined)
	
	If DafaultExportingHSCode = Undefined Then
		
		DafaultExportingHSCode = DafaultExportingHSCode();
		
	EndIf;
	
	ExportingHSCodeChoiceList = Items.ExportingHSCode.ChoiceList;
	ExportingHSCodeChoiceList.Clear();
	
	If Not IsBlankString(DafaultExportingHSCode) Then
		
		ExportingHSCodeChoiceList.Add(DafaultExportingHSCode);
		
	EndIf;
	
EndProcedure

#EndRegion