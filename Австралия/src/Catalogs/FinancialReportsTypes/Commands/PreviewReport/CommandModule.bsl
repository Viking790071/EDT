
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Form = CommandExecuteParameters.Source;
	If Form.FormName = "Catalog.FinancialReportsTypes.Form.ItemForm" Then
		ReportType = Form.Object.Ref;
		ReportsSet = Form.ReportsSet;
		If Not ValueIsFilled(ReportType) Or Form.Modified Then
			Response = Undefined;
			ShowQueryBox(
				New NotifyDescription("CommandProcessingEnd", 
					ThisObject,
					New Structure("Form, ReportsSet, ReportType", Form, ReportsSet, ReportType)),
				Nstr("en = 'All modifications will be saved.
					|Continue?'; 
					|ru = 'Все изменения будут сохранены.
					|Продолжить?';
					|pl = 'Wszystkie modyfikacje zostaną zapisane.
					|Dalej?';
					|es_ES = 'Todas las modificaciones serán guardadas.
					|¿Continuar?';
					|es_CO = 'Todas las modificaciones serán guardadas.
					|¿Continuar?';
					|tr = 'Tüm değişiklikler kaydedilecektir.
					| Devam et?';
					|it = 'Tutte le modifiche saranno salvate.
					|Continuare?';
					|de = 'Alle Änderungen werden gespeichert.
					|Fortsetzen?'"),
				QuestionDialogMode.YesNo);
			Return;
		EndIf;
	EndIf;
	
	GenerateReport(Form, ReportsSet, ReportType);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CommandProcessingEnd(Result, AdditionalParameters) Export
	
	Form = AdditionalParameters.Form;
	ReportsSet = AdditionalParameters.ReportsSet;
	ReportType = AdditionalParameters.ReportType;
	
	If Result = DialogReturnCode.Yes Then
		Form.Write();
	ElsIf Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	GenerateReport(Form, ReportsSet, ReportType);
	
EndProcedure

&AtClient
Procedure GenerateReport(Val Form, Val ReportsSet, Val ReportType)
	
	If Form.FormName = "Catalog.FinancialReportsTypes.Form.ListForm" Then
		CurrentData = Form.Items.List.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		If Not CurrentData.IsFolder Then
			ReportType = CurrentData.Ref;
		EndIf;
	EndIf;
	
	If ReportType <> Undefined Then
		Filter = New Structure("ReportsSet, ReportType", ReportsSet, ReportType);
		FormParameters = New Structure("Filter, GenerateReport", Filter, True);
		OpenForm("Report.FinancialReport.Form.ReportForm", FormParameters, Form, True);
	EndIf;
	
EndProcedure

#EndRegion