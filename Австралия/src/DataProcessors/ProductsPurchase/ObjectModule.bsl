#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns information about external data processor.
Function ExternalDataProcessorInfo() Export
	
	RegistrationParameters = AdditionalReportsAndDataProcessors.ExternalDataProcessorInfo("2.1.3.1");
	
	RegistrationParameters.Type = AdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalDataProcessor();
	RegistrationParameters.Version = "1.0";
	RegistrationParameters.SafeMode = True;
	
	NewCommand = RegistrationParameters.Commands.Add();
	NewCommand.Presentation = NStr("en = 'Goods demand calculation'; ru = 'Расчет потребности товаров';pl = 'Obliczanie zapotrzebowania na materiały';es_ES = 'Cálculo de la demanda de mercancías';es_CO = 'Cálculo de la demanda de mercancías';tr = 'Ürün talebi hesaplama';it = 'Calcolo del fabbisogno di merci';de = 'Warenbedarfsberechnung'");
	NewCommand.ID = "ProductsNeedCalculation";
	NewCommand.Use = AdditionalReportsAndDataProcessorsClientServer.CommandTypeOpenForm();
	NewCommand.ShowAlert = False;
	
	Return RegistrationParameters;
	
EndFunction

#EndRegion

#EndIf