
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure("CounterpartiesInitialValue", CommandParameter);
	If CommandParameter.Count() > 0 Then
		UniqueKey = String(CommandParameter[0]);
	Else
		UniqueKey = CommandExecuteParameters.Uniqueness;
	EndIf;
	
	PrintParameters = New Structure("ID, PrintManager", "ContactInformationCard", "Catalog.Counterparties");
	FormParameters.Insert("PrintParameters",	PrintParameters);
	FormParameters.Insert("Window",				CommandExecuteParameters.Window);
	FormParameters.Insert("URL",				CommandExecuteParameters.URL);
	FormParameters.Insert("UniqueKey",			UniqueKey);
	
	If Not DisplayPrintOption(FormParameters, CommandExecuteParameters.Source) Then
		OpenForm(
			"Catalog.Counterparties.Form.ContactInformationForm",
			FormParameters,
			CommandExecuteParameters.Source,
			UniqueKey,
			CommandExecuteParameters.Window,
			CommandExecuteParameters.URL);
	EndIf
	
EndProcedure

&AtClient
Function DisplayPrintOption(FormParameters, FormOwner) Export
    
	PrintParameters = FormParameters.PrintParameters;
	If Not PrintManagementServerCallDrive.CheckPrintFormSettings(PrintParameters.ID) Then
        PrintParameters.Insert("Result", Undefined);
		Return False;    
	EndIf; 
	
	DisplayPrintOption = PrintManagementServerCallDrive.GetFunctionalOptionValue("DisplayPrintOptionsBeforePrinting");
	If DisplayPrintOption Then
		
		ObjectsArray = FormParameters.CounterpartiesInitialValue;
		AdditionalParameters = New Structure("MetadataObject, Result", ObjectsArray[0]);
		PrintParameters.Insert("AdditionalParameters", AdditionalParameters);
		
		PrnOptions = PrintManagementServerCallDrive.GetPrintOptionsByUsers(ObjectsArray[0], PrintParameters.ID, Undefined);
		
		If PrnOptions.DoNotShowAgain Then
			
			AdditionalParameters.Result = PrnOptions;
			OpenForm(
				"Catalog.Counterparties.Form.ContactInformationForm",
				FormParameters,
				FormOwner,
				FormParameters.UniqueKey,
				FormParameters.Window,
				FormParameters.URL);
		Else
			NotifyDescription = New NotifyDescription("ExecutePrintCommandContinue", ThisObject, FormParameters);
			Form = OpenForm("DataProcessor.PrintOptions.Form.Form", PrintParameters, FormOwner,,,,NotifyDescription);
		EndIf;
		Return True;
	Else
		Return False;
	EndIf
	
EndFunction

// Continues execution of the ExecutePrintCommand procedure.
&AtClient
Procedure ExecutePrintCommandContinue(Result, Params) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Params.PrintParameters.AdditionalParameters.Insert("Result", Result); 
	OpenForm(
		"Catalog.Counterparties.Form.ContactInformationForm",
		Params,
		,
		Params.UniqueKey,
		Params.Window,
		Params.URL);
	
EndProcedure    

