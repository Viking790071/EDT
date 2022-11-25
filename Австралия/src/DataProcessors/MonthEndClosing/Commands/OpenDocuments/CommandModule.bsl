
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CommandSource = CommandExecuteParameters.Source;
	
	If Not ValueIsFilled(CommandSource.Company) Then
		
		Notify("MonthEndClosingDataProcessorOpenDocumentsNotSelectedCompany");
		
		Return;
	
	EndIf;
	
	Filter = New Structure("Company", CommandSource.Company);
	ListParameters = New Structure("Filter, CurYear, CurMonth", 
		Filter,
		Format(CommandSource.CurYear,"NG=0"),
		Format(CommandSource.CurMonth,"ND=2; NLZ=; NG=0"));
	
	OpenForm(
		"DataProcessor.MonthEndClosing.Form.DocumentsListForm",
		ListParameters,
		CommandSource,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion