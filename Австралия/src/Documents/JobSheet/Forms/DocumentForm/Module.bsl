
#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// Gets data set from server.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData, ObjectDate)
	
	If StructureData.Property("Characteristic") Then
		Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
			ObjectDate, 
			StructureData.Characteristic);
	Else
		Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
			ObjectDate, 
			Catalogs.ProductsCharacteristics.EmptyRef());
	EndIf;
	StructureData.Insert("Specification", Specification);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Receives employee ID with the server.
//
Function GetTabNumber(Performer)
	
	Return Performer.Code;
	
EndFunction

&AtServer
// Procedure fills team members.
//
Procedure FillTeamMembersAtServer()

	Document = FormAttributeToValue("Object");
	Document.FillTeamMembers();
	ValueToFormAttribute(Document, "Object");
	Modified = True;	

EndProcedure

&AtServerNoContext
// It receives data set from server to operation.
//
Function GetOperationData(StructureData)
	
	StructureData.Insert("TimeNorm", StructureData.Products.TimeNorm);
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	StructureData.Insert("PriceKind", Catalogs.PriceTypes.Accounting);
	StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
	StructureData.Insert("Factor", 1);
	StructureData.Insert("AmountIncludesVAT", Catalogs.PriceTypes.Accounting.PriceIncludesVAT);
	
	StructureData.Insert("Price", DriveServer.GetProductsPriceByPriceKind(StructureData));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateDuration()

	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.StandardHours = CurrentRow.TimeNorm * CurrentRow.QuantityFact;	
	
EndProcedure

&AtClient
// Procedure calculates operation performing cost.
//
// Parameters:
//  No.
//
Procedure CalculateCost()

	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.Cost = CurrentRow.Tariff * CurrentRow.QuantityFact;
		
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

&AtServer
// Procedure sets availability of form items according to the type of server.
//
// Parameters:
//  No.
//
Procedure SetVisibleAndEnabledFromExecutor()
	
	If TypeOf(Object.Performer) = Type("CatalogRef.Teams") Then
		
		Items.GroupTeamMembers.Visible 				= True;
		Items.FillTeamMembers.Visible 			= True;
		Items.TabNumber.Visible 						= False;
		
	Else
		
		Items.GroupTeamMembers.Visible 				= False;
		Items.FillTeamMembers.Visible 			= False;
		Items.TabNumber.Visible 						= True;
		
		Object.TeamMembers.Clear();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed);
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis)
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		Object.DocumentCurrency = DriveServer.GetPresentationCurrency(Object.Company);
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	If TypeOf(Object.Performer) = Type("CatalogRef.Employees") Then
		TabNumber = Object.Performer.Code;
	Else
		TabNumber = "";
	EndIf;
	
	SetVisibleAndEnabledFromExecutor();
	Items.ClosingDate.AutoMarkIncomplete = Object.Closed;
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		If Items.Find("TeamMembersEmployeeCode") <> Undefined Then
			Items.TeamMembersEmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		NotifyWorkCalendar = True;
		DocumentModified = False;
	EndIf;
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
// Performs initial attributes forms filling.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		DocumentModified = True;	
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field Performer.
//
Procedure AssigneeOnChange(Item)
	
	SetVisibleAndEnabledFromExecutor();
	Object.TeamMembers.Clear();
	
	If TypeOf(Object.Performer) = Type("CatalogRef.Employees") Then
		TabNumber = GetTabNumber(Object.Performer);
	Else
		TabNumber = "";
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute ItIsClosed.
//
Procedure ClosedOnChange(Item)
	
	If Not ValueIsFilled(Object.ClosingDate) AND Object.Closed Then
		Object.ClosingDate = CommonClient.SessionDate();	
	EndIf;
	
	If Object.Closed Then
		Items.ClosingDate.AutoMarkIncomplete = True;
	Else	
		Items.ClosingDate.AutoMarkIncomplete = False;
		ClearMarkIncomplete();
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute CloseDate.
//
Procedure ClosingDateOnChange(Item)
	
	If ValueIsFilled(Object.ClosingDate) Then
		Object.Closed = True;	
	EndIf; 
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#Region TablePartsAttributeEventHandlers

&AtClient
// Procedure - event handler OnChange of attribute Period of tabular section Operations.
//
Procedure OperationsPeriodOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	StructureData = New Structure();
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate", 	CurrentRow.Period);
	StructureData.Insert("Products", 	CurrentRow.Operation);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	CurrentRow.Tariff = GetOperationData(StructureData).Price;
	
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Operation of tabular section Operations.
//
Procedure OperationsOperationOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	StructureData = New Structure();
	StructureData.Insert("Company", 			Object.Company);
	StructureData.Insert("ProcessingDate", 	CurrentRow.Period);
	StructureData.Insert("Products", 	CurrentRow.Operation);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	ResultStructure 				= GetOperationData(StructureData);
	CurrentRow.Tariff 			= ResultStructure.Price;
	CurrentRow.MeasurementUnit 	= ResultStructure.MeasurementUnit;
	CurrentRow.TimeNorm 		= ResultStructure.TimeNorm;
	
	CalculateDuration();
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure OperationsProductsOnChange(Item)
	
	TabularSectionRow = Items.Operations.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure OperationCharacteristicChange(Item)
	
	TabularSectionRow = Items.Operations.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the Quantity attribute of the Operation tabular section.
//
Procedure OperationsQuantityOnChange(Item)
	
	CalculateDuration();
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the StandartHours attribute of the Operation tabular section.
//
Procedure OperationsTimeNormOnChange(Item)
	
	CalculateDuration();
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the StandardHours attribute of the Operations tabular section.
//
Procedure OperationsStandardHoursOnChange(Item)
	
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of Tariff attribute of Operations tabular section.
//
Procedure OperationsTariffOnChange(Item)
	
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure OperationsMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Operations.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
	 OR TabularSectionRow.Tariff = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Tariff = TabularSectionRow.Tariff * StructureData.Factor / StructureData.CurrentFactor;
		TabularSectionRow.TimeNorm = TabularSectionRow.TimeNorm * StructureData.Factor / StructureData.CurrentFactor;
		CalculateDuration();
		CalculateCost();
	EndIf;
	
	CalculateCost();
	
EndProcedure

&AtClient
// Procedure - handler of the OnChange event of the Employee attribute of the TeamMembers tabular section.
//
Procedure TeamMembersEmployeeOnChange(Item)
	
	Items.TeamMembers.CurrentData.LPF = 1;
	
EndProcedure

&AtClient
// Procedure - command handler FillTeamMembers.
//
Procedure FillTeamMembers(Command)
	
	FillTeamMembersAtServer();
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion
