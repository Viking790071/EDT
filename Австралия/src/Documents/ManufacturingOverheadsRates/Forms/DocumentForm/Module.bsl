
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	SetAccountingPolicyValues();
	SetVisibleAndEnable();
	
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

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CompanyOnChange(Item)
	
	SetAccountingPolicyValues();
	
	SetVisibleAndEnable();
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure RatesGLAccountOnChange(Item)
	
	CurData = Items.Rates.CurrentData;
	If CurData <> Undefined Then
		
		StructureData = New Structure("
		|TabName,
		|Object,
		|GLAccount,
		|ExpenseItem");
		StructureData.Object = Object;
		StructureData.TabName = "Rates";
		FillPropertyValues(StructureData, CurData);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(CurData, StructureData);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetAccountingPolicyValues()
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Object.Company);
	Object.ManufacturingOverheadsAllocationMethod = AccountingPolicy.ManufacturingOverheadsAllocationMethod;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	SetAccountingPolicyValues();
	SetVisibleAndEnable();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnable()
	
	AllocationMethod = Object.ManufacturingOverheadsAllocationMethod;
	
	PlantwideAllocation = (AllocationMethod = Enums.ManufacturingOverheadsAllocationMethods.PlantwideAllocation);
	DepartmentalAllocation = (AllocationMethod = Enums.ManufacturingOverheadsAllocationMethods.DepartmentalAllocation);
	ActivityBasedCosting = (AllocationMethod = Enums.ManufacturingOverheadsAllocationMethods.ActivityBasedCosting);
	
	Items.RatesActivity.Visible = ActivityBasedCosting;
	Items.RatesBusinessUnit.Visible = DepartmentalAllocation OR ActivityBasedCosting;
	
EndProcedure

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
