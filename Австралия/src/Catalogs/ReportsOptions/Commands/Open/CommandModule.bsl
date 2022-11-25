#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	Option = CommandParameter;
	Form = CommandExecuteParameters.Source;
	If TypeOf(Form) = Type("ClientApplicationForm") Then
		If Form.FormName = "Catalog.ReportsOptions.Form.ListForm" Then
			Option = Form.Items.List.CurrentData;
		ElsIf Form.FormName = "Catalog.ReportsOptions.Form.ItemForm" Then
			Option = Form.Object;
		EndIf;
	Else
		Form = Undefined;
	EndIf;
	
	ReportsOptionsClient.OpenReportForm(Form, Option);
EndProcedure

#EndRegion
