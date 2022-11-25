#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	If NOT AllowedEditDocumentPrices Then
		
		CommonClientServer.SetFormItemProperty(Items, "FormCreate", "Enabled", False);
		CommonClientServer.SetFormItemProperty(Items, "FormChange", "Enabled", False);
		CommonClientServer.SetFormItemProperty(Items, "FormCopy", "Enabled", False);
		
	EndIf;
	
	CommonClientServer.SetFormItemProperty(Items, "FormGenerate", "Visible", NOT CommonClientServer.IsMobileClient());
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Genegate(Command)
	
	CurrentRowData = Items.List.CurrentData;
	
	If CurrentRowData <> Undefined Then
		
		OpenForm("DataProcessor.GenerationPriceLists.Form", New Structure("PriceList", CurrentRowData.Ref), ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion