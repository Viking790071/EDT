#Region Public

Function DisplayPrintOption(ObjectsArray, OpeningParameters, FormOwner, UniqueKey, PrintParameters) Export
    
	If Not PrintManagementServerCallDrive.CheckPrintFormSettings(PrintParameters.ID) Then
		If OpeningParameters.PrintParameters.Property("AdditionalParameters") Then
			OpeningParameters.PrintParameters.AdditionalParameters.Insert("Result", Undefined);
		EndIf;
		
		Return False;    
	EndIf; 
	
    If ValueIsFilled(OpeningParameters.PrintParameters) AND PrintParameters.Property("AdditionalParameters") Then 
        OpeningParameters.PrintParameters.AdditionalParameters.Insert("Result", Undefined);
    Else
        // The value "OpeningParameters" is not filled if the print proc is called not from the document/documents list.
        If ValueIsFilled(PrintParameters) Then 
		    PrintParameters.Insert("AdditionalParameters", New Structure("Result", New Structure("Copies", 1)));
            PrintParameters.AdditionalParameters.Insert("FormTitle", PrintParameters.FormTitle);
            PrintParameters.AdditionalParameters.Insert("PrintInfo", PrintParameters.PrintInfo);
        EndIf;    
        OpenForm("CommonForm.PrintDocuments", OpeningParameters, FormOwner, UniqueKey);
        Return True;
	EndIf;
	
	DisplayPrintOption = PrintManagementServerCallDrive.GetFunctionalOptionValue("DisplayPrintOptionsBeforePrinting");
	If DisplayPrintOption Then

		Params =  New Structure;
		Params.Insert("OpeningParameters", OpeningParameters);
		Params.Insert("FormOwner", FormOwner);
		Params.Insert("UniqueKey", UniqueKey);
		
		PrintParameters.AdditionalParameters.Insert("MetadataObject", ObjectsArray[0]);
		
		PrnOptions = PrintManagementServerCallDrive.GetPrintOptionsByUsers(ObjectsArray[0], PrintParameters.ID, Undefined);
		
		If PrnOptions.Discount <> Undefined
			Or PrnOptions.DoNotShowAgain Then
			OpeningParameters.PrintParameters.AdditionalParameters.Result = PrnOptions;
			OpenForm("CommonForm.PrintDocuments", OpeningParameters, FormOwner, UniqueKey);
		Else
			NotifyDescription = New NotifyDescription("ExecutePrintCommandContinue", ThisObject, Params);
			OpenForm("DataProcessor.PrintOptions.Form.Form",PrintParameters,,,,,NotifyDescription);
		EndIf;
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Continues execution of the ExecutePrintCommand procedure.
Procedure ExecutePrintCommandContinue(Result, Params) Export
	If Result = Undefined Then
		Return;
	EndIf;
    Params.OpeningParameters.PrintParameters.AdditionalParameters.Insert("Result", Result); 
    OpenForm("CommonForm.PrintDocuments", Params.OpeningParameters, Params.FormOwner, Params.UniqueKey);    
EndProcedure    

Procedure GeneratePrintFormForExternalUsers(Refs, PrintManagerName, TemplateName, FormTitle, FormOwner, UniqueKey) Export
	
	If TypeOf(Refs) <> Type("Array") Then
		RefsArray = New Array;
		RefsArray.Add(Refs);
	Else
		RefsArray = Refs;
	EndIf;
	
	OpenParameters = New Structure("PrintManagerName, TemplatesNames, CommandParameter, PrintParameters");
	OpenParameters.PrintManagerName = PrintManagerName;
	OpenParameters.TemplatesNames   = TemplateName;
	OpenParameters.CommandParameter	 = RefsArray;
	
	PrintParameters = New Structure("FormCaption, ID, AdditionalParameters");
	PrintParameters.FormCaption = FormTitle;
	PrintParameters.ID = TemplateName;
	PrintParameters.AdditionalParameters = New Structure("Result");
	OpenParameters.PrintParameters = PrintParameters;
	
	If Not DisplayPrintOption(RefsArray, OpenParameters, FormOwner, UniqueKey, OpenParameters.PrintParameters) Then
		OpenForm("CommonForm.PrintDocuments", OpenParameters, ThisObject, UniqueKey);
	EndIf;
	
EndProcedure

#EndRegion
