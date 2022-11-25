#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InstancesParameters = Parameters.InstancesParameters;
	FillPropertyValues(ThisObject, InstancesParameters);
	Items.OpenForms.Visible = InstancesParameters.OpenFormsFlag;
	
	FinancialReportingServer.FillReportCurrency(Items.Resource);
	ChoiceList = Items.Resource.ChoiceList;
	If IsBlankString(Resource) And ChoiceList.Count() Then
		Resource = Items.Resource.ChoiceList[0].Value;
	EndIf;
	
	Items.BusinessUnit.Visible = Catalogs.BusinessUnits.AccountingByBusinessUnits();
	Items.LineOfBusiness.Visible = Catalogs.LinesOfBusiness.AccountingByLinesOfBusiness();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectPeriod(Command)
	
	ChoiceParameters = New Structure("BeginOfPeriod, EndOfPeriod", BeginOfPeriod, EndOfPeriod);
	NotifyDescription = New NotifyDescription("SelectPeriodEnd", ThisObject);
	OpenForm("CommonForm.SelectPeriod", ChoiceParameters, Items.SelectPeriod, , , , NotifyDescription);
	
EndProcedure

&AtClient
Procedure Generate(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	InstancesParameters = FinancialReportingClientServer.ReportGenerationNewParameters();
	FillPropertyValues(InstancesParameters, ThisObject);
	InstancesParameters.Insert("Resource", Resource);
	Close(InstancesParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectPeriodEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	FillPropertyValues(ThisObject, Result, "BeginOfPeriod, EndOfPeriod");
	
EndProcedure

#EndRegion