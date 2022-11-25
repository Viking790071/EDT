
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseAdditionalReportsAndDataProcessors = GetFunctionalOption("UseAdditionalReportsAndDataProcessors");
	Items.BankClassifierRightColumnGroup.Visible = UseAdditionalReportsAndDataProcessors;
	Items.ExchangeRateRightColumnGroup.Visible = UseAdditionalReportsAndDataProcessors 
												And Not Constants.UseSeveralCompanies.Get();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

#EndRegion

// StandardSubsystems.Banks
&AtClient
Procedure DataProcessorBankClassifierImportProcess(Command)
	OpenForm("Catalog.BankClassifier.Form.ImportClassifier");
EndProcedure

&AtClient
Procedure ConfigureImportBankClassifier(Command)
	
	OpenForm("Constant.BankClassifierImportProcessor.ConstantsForm");
	
EndProcedure
// End StandardSubsystems.Banks

// StandardSubsystems.Currencies
&AtClient
Procedure DataProcessorExchangeRatesImportProcess(Command)
	
	CurrencyRateOperationsClientDrive.OpenFormOfExchangeRatesImportProcessor();
	
EndProcedure

&AtClient
Procedure ConfigureImportCurrencyRate(Command)
	
	OpenForm("CommonForm.ExchangeRatesImportProcessor");
	
EndProcedure

// End StandardSubsystems.Currencies

#Region ServiceProceduresAndFunctions

&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

#EndRegion

