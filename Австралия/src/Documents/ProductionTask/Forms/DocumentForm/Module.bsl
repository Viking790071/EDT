#Region Variables

&AtClient
Var UseProductionTasksInMobileClient;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	BasisDocument = Object.BasisDocument;
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	SetOperationChoiceParameters();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer (ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UseProductionTasksInMobileClient = UseProductionTasksInMobileClient();
	FormManagement();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ProductionTaskStatuseChanged" Then
		
		If TypeOf(Parameter) = Type("Array") And Parameter.Find(Object.Ref) <> Undefined Then
			ThisObject.Read();
			FormManagement();
		EndIf;
		
	ElsIf EventName = "WorkInProgressChanged" Then
		
		If Parameter = Object.BasisDocument Then
			ThisObject.RefreshDataRepresentation(Items.FinishedProduct);
			FormManagement();
		EndIf;
		
	ElsIf EventName = "EmployeeChanged" Then
		
		If Parameter = Object.Ref Then
			ThisObject.Read();
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	If Not CurrentObject.IsNew() Then
		CurrentObject.AdditionalProperties.Insert("DoNotWriteStatus", True);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	FormManagement();
	Notify("RefreshProductionOrderQueue");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'The Production task tabs will be populated with the data from the selected Work-in-progress. Do you want to continue?'; ru = '?????????????? ???????????????????????????????? ?????????? ?????????? ?????????????????? ?????????????? ???? ???????????????????? ?????????????????? ""?????????????????????????? ????????????????????????"". ?????????????????????';pl = 'Karty zada?? produkcyjnych zostan?? wype??nione danymi z wybranej Pracy w toku. Czy chcesz kontynuowa???';es_ES = 'Las pesta??as de las tareas de producci??n se llenar??n con los datos del Trabajo en progreso seleccionado. ??Quiere continuar?';es_CO = 'Las pesta??as de las tareas de producci??n se llenar??n con los datos del Trabajo en progreso seleccionado. ??Quiere continuar?';tr = '??retim g??revi sekmeleri se??ilen ????lem biti??indeki verilerle doldurulacak. Devam etmek istiyor musunuz?';it = 'Le schede dell''Incarico di produzione sar?? compilato con i dati dal Lavoro in corso selezionato. Continuare?';de = 'Die Registerkarten der Produktionsaufgaben werden mit dem Datum aus der ausgew??hlten Arbeit in Bearbeitung aufgef??llt. M??chten Sie fortfahren?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure
	
	
&AtClient
Procedure WorkcenterTypeOnChange(Item)
	
	If Not ValueIsFilled(Object.WorkcenterType) 
		And ValueIsFilled(Object.Workcenter) Then
		
		Object.Workcenter = PredefinedValue("Catalog.CompanyResources.EmptyRef");
		
	EndIf;
	
	SetEnabledItemWorkcenter();
	
EndProcedure

&AtClient
Procedure OperationOnChange(Item)
	
	OperationOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectWorkInProgress();
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'The Production task tabs will be populated with the data from the selected Work-in-progress. Do you want to continue?'; ru = '?????????????? ???????????????????????????????? ?????????? ?????????? ?????????????????? ?????????????? ???? ???????????????????? ?????????????????? ""?????????????????????????? ????????????????????????"". ?????????????????????';pl = 'Karty zada?? produkcyjnych zostan?? wype??nione danymi z wybranej Pracy w toku. Czy chcesz kontynuowa???';es_ES = 'Las pesta??as de las tareas de producci??n se llenar??n con los datos del Trabajo en progreso seleccionado. ??Quiere continuar?';es_CO = 'Las pesta??as de las tareas de producci??n se llenar??n con los datos del Trabajo en progreso seleccionado. ??Quiere continuar?';tr = '??retim g??revi sekmeleri se??ilen ????lem biti??indeki verilerle doldurulacak. Devam etmek istiyor musunuz?';it = 'Le schede dell''Incarico di produzione sar?? compilato con i dati dal Lavoro in corso selezionato. Continuare?';de = 'Die Registerkarten der Produktionsaufgaben werden mit dem Datum aus der ausgew??hlten Arbeit in Bearbeitung aufgef??llt. M??chten Sie fortfahren?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtClient
Procedure FormManagement()
	
	RefreshStatus();
	
	WIPOperationIsDone = WIPOperationIsDone(Object.BasisDocument, Object.Operation, Object.ConnectionKey);
	
	TaskIsBlocked = False;
	
	If WIPOperationIsDone Then
		
		TaskIsBlocked = True;
		InfoMessage = NStr("en = 'This Production task is related to a completed operation. Editing is restricted for this task.'; ru = '?????? ???????????????????????????????? ???????????? ?????????????? ?? ?????????????????????? ??????????????????. ???????????????????????????? ???????? ???????????? ??????????????????.';pl = 'To Zadanie produkcyjne jest zwi??zane z wykonan?? operacj??. Edycja jest ograniczona dla tego zadania.';es_ES = 'Esta tarea de producci??n est?? relacionada con una operaci??n finalizada. La edici??n est?? restringida para esta tarea.';es_CO = 'Esta tarea de producci??n est?? relacionada con una operaci??n finalizada. La edici??n est?? restringida para esta tarea.';tr = 'Bu ??retim g??revi, tamamlanm???? bir i??lemle ba??lant??l??. Bu g??rev i??in d??zenleme k??s??tlamas?? var.';it = 'Questo Incarico di produzione ?? correlato a una operazione completata. La modifica ?? limitata per questo incarico.';de = 'Diese Produktionsaufgabe bezieht sich auf eine abgeschlossene Aufgabe. Bearbeitungsrechte sind f??r diese Aufgabe eingeschr??nkt.'");
		
	ElsIf Object.Status = PredefinedValue("Enum.ProductionTaskStatuses.Canceled") Then
		
		TaskIsBlocked = True;
		InfoMessage = NStr("en = 'This Production task is canceled.'; ru = '?????? ???????????????????????????????? ???????????? ????????????????.';pl = 'To Zadanie produkcyjne zosta??o anulowane.';es_ES = 'Se ha cancelado esta tarea de producci??n.';es_CO = 'Se ha cancelado esta tarea de producci??n.';tr = 'Bu ??retim g??revi iptal edildi.';it = 'Questo Incarico di produzione ?? annullato.';de = 'Diese Produktionsaufgabe wurde abgebrochen.'");
		
	ElsIf Object.Status = PredefinedValue("Enum.ProductionTaskStatuses.Completed") Then
		
		TaskIsBlocked = True;
		InfoMessage = NStr("en = 'This Production task is completed.'; ru = '?????? ???????????????????????????????? ???????????? ??????????????????.';pl = 'To Zadanie produkcyjne jest zako??czone.';es_ES = 'Se ha completado esta tarea de producci??n.';es_CO = 'Se ha completado esta tarea de producci??n.';tr = 'Bu ??retim g??revi tamamland??.';it = 'Questo Incarico di produzione ?? completato.';de = 'Diese Produktionsaufgabe ist abgeschlossen.'");
		
	ElsIf Object.Status = PredefinedValue("Enum.ProductionTaskStatuses.Suspended") Then
		
		TaskIsBlocked = True;
		InfoMessage = NStr("en = 'This Production task is suspended. To resume working on it, click ""Actions"" and select ""Start"".'; ru = '?????? ???????????????????????????????? ???????????? ????????????????????????????. ?????????? ?????????????????????? ???????????? ?????? ??????, ?????????????? ""????????????????"" ?? ???????????????? ""??????????????????"".';pl = 'To Zadanie produkcyjne jest zawieszone. Aby wznowi?? prac?? nad nim, kliknij ""Czynno??ci"". i wybierz ""Zacznij"".';es_ES = 'Se ha suspendido esta tarea de producci??n. Para reanudar el trabajo, haga clic en ""Acciones"" y seleccione ""Iniciar"".';es_CO = 'Se ha suspendido esta tarea de producci??n. Para reanudar el trabajo, haga clic en ""Acciones"" y seleccione ""Iniciar"".';tr = 'Bu ??retim g??revi ask??ya al??nd??. ??al????maya devam etmek i??in ""Eylemler"" ve ""Ba??la"" yolunu takip edin.';it = 'Questo Incarico di produzione ?? sospeso. Per riprendere il lavoro, clicca su ""Azioni"" e selezionare ""Avvia"".';de = 'Diese Produktionsaufgabe ist suspendiert. Um die Arbeit an dieser Aufgabe fortzusetzen, klicken Sie auf ""Aktionen"" und w??hlen Sie ""Start"" aus.'");
		
	ElsIf Object.Status = PredefinedValue("Enum.ProductionTaskStatuses.Split") Then
		
		TaskIsBlocked = True;
		InfoMessage = NStr("en = 'This Production task is split.'; ru = '?????? ???????????????????????????????? ???????????? ??????????????????.';pl = 'To Zadanie produkcyjne jest rozdzielone.';es_ES = 'Se ha dividido esta tarea de producci??n.';es_CO = 'Se ha dividido esta tarea de producci??n.';tr = 'Bu ??retim g??revi b??l??nd??.';it = 'Questo Incarico di produzione ?? diviso.';de = 'Diese Produktionsaufgabe ist aufgeteilt.'");
		
	EndIf;
	
	If UseProductionTasksInMobileClient Then
		
		FormShowInListProductionTask = Items.Find("FormShowInListProductionTask");
		If FormShowInListProductionTask <> Undefined Then
			FormShowInListProductionTask.Visible = False;
		EndIf;
		
	EndIf;
	
	SetGroupChangeStatusAvailability();
	
	Items.InfoMessage.Visible = TaskIsBlocked;
	Items.Pages.ReadOnly = TaskIsBlocked;
	
	Items.ParentTask.Visible = ValueIsFilled(Object.ParentTask);
	
	SetEnabledItemWorkcenter();
	
EndProcedure

&AtClient
Procedure SetEnabledItemWorkcenter()
	
	Items.Workcenter.Enabled = ValueIsFilled(Object.WorkcenterType);
	
EndProcedure

&AtClient
Procedure SetGroupChangeStatusAvailability()
	
	Status = Object.Status;
	
	Items.FormInformationRegisterProductionTaskStatusesCompleted.Enabled = False;
	Items.FormInformationRegisterProductionTaskStatusesSuspend.Enabled = False;
	Items.FormInformationRegisterProductionTaskStatusesCancel.Enabled = False;
	Items.FormInformationRegisterProductionTaskStatusesInProgress.Enabled = False;
	Items.FormDocumentProductionTaskSplit.Enabled = False;
	
	If Status = PredefinedValue("Enum.ProductionTaskStatuses.Open") Then
		
		Items.FormInformationRegisterProductionTaskStatusesCompleted.Enabled = True;
		Items.FormInformationRegisterProductionTaskStatusesCancel.Enabled = True;
		Items.FormInformationRegisterProductionTaskStatusesInProgress.Enabled = True;
		Items.FormDocumentProductionTaskSplit.Enabled = True;
		
	ElsIf Status = PredefinedValue("Enum.ProductionTaskStatuses.Suspended") Then
		
		Items.FormInformationRegisterProductionTaskStatusesCompleted.Enabled = True;
		Items.FormInformationRegisterProductionTaskStatusesCancel.Enabled = True;
		Items.FormInformationRegisterProductionTaskStatusesInProgress.Enabled = True;
		Items.FormDocumentProductionTaskSplit.Enabled = True;
		
	ElsIf Status = PredefinedValue("Enum.ProductionTaskStatuses.InProgress") Then
		
		Items.FormInformationRegisterProductionTaskStatusesCompleted.Enabled = True;
		Items.FormInformationRegisterProductionTaskStatusesSuspend.Enabled = True;
		Items.FormInformationRegisterProductionTaskStatusesCancel.Enabled = True;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function WIPOperationIsDone(WIP, Activity, ConnectionKey)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ManufacturingOperationActivities.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|WHERE
	|	ManufacturingOperationActivities.Ref = &WIP
	|	AND ManufacturingOperationActivities.ConnectionKey = &ConnectionKey
	|	AND ManufacturingOperationActivities.Activity = &Activity
	|	AND ManufacturingOperationActivities.Done";
	
	Query.SetParameter("WIP", WIP);
	Query.SetParameter("Activity", Activity);
	Query.SetParameter("ConnectionKey", ConnectionKey);
	
	QueryResult = Query.Execute();
	Return Not QueryResult.IsEmpty();
	
EndFunction

&AtServer
Procedure SetOperationChoiceParameters()
	
	If ValueIsFilled(Object.BasisDocument) Then
		
		Query = New Query;
		Query.Text = 
			"SELECT DISTINCT
			|	ManufacturingOperationActivities.Activity AS Activity
			|FROM
			|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
			|WHERE
			|	ManufacturingOperationActivities.Ref = &Ref";
		
		Query.SetParameter("Ref", Object.BasisDocument);
		
		OperationsArray = Query.Execute().Unload().UnloadColumn("Activity");
		
		Refs = New FixedArray(OperationsArray);
		
		NewParameter = New ChoiceParameter("Filter.Ref", Refs);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.Operation.ChoiceParameters = NewParameters;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OperationOnChangeAtServer()
	
	Object.OperationQuantity = 0;
	Object.Output = False;
	Object.StandardTime = 0;
	Object.StandardTimeInUOM = 0;
	Object.TimeUOM = Catalogs.TimeUOM.EmptyRef();
	
	If ValueIsFilled(Object.Operation) And ValueIsFilled(Object.BasisDocument) Then
		
		Query = New Query;
		Query.Text = 
			"SELECT TOP 1
			|	ManufacturingOperationActivities.ConnectionKey AS ConnectionKey
			|FROM
			|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
			|WHERE
			|	ManufacturingOperationActivities.Ref = &Ref
			|	AND ManufacturingOperationActivities.Activity = &Activity";
		
		Query.SetParameter("Activity", Object.Operation);
		Query.SetParameter("Ref", Object.BasisDocument);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			
			Document = FormAttributeToValue("Object");
			Document.FillByWorkInProgress(
				Object.BasisDocument,
				SelectionDetailRecords.ConnectionKey);
			ValueToFormAttribute(Document, "Object");
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function UseProductionTasksInMobileClient()

	Return AccessManagement.HasRole("UseProductionTasksInMobileClient");

EndFunction

#Region TaskStatus

&AtClient
Procedure RefreshStatus()
	
	StatusStructure = GetStatus(Object.Ref);
	FillPropertyValues(ThisObject, StatusStructure, "SuspendReason, Comment");
	
	Items.GroupStatusDetails.Visible = (Object.Status = PredefinedValue("Enum.ProductionTaskStatuses.Suspended"));
	
EndProcedure

&AtServerNoContext
Function GetStatus(ProductionTask)
	
	ReturnStructure = New Structure("Status, SuspendReason, Comment");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductionTaskStatusesSliceLast.Status AS Status,
	|	ProductionTaskStatusesSliceLast.SuspendReason AS SuspendReason,
	|	ProductionTaskStatusesSliceLast.Comment AS Comment
	|FROM
	|	InformationRegister.ProductionTaskStatuses.SliceLast(, ProductionTask = &ProductionTask) AS ProductionTaskStatusesSliceLast";
	
	Query.SetParameter("ProductionTask", ProductionTask);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(ReturnStructure, SelectionDetailRecords);
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

#EndRegion

#Region FillByBasis

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument();
		If BasisDocument <> Object.BasisDocument Then
			BasisDocument = Object.BasisDocument;
		EndIf;
	Else
		Object.BasisDocument = BasisDocument;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByDocument()
	
	Document = FormAttributeToValue("Object");
	Document.Fill(Object.BasisDocument);
	ValueToFormAttribute(Document, "Object");
	
	SetOperationChoiceParameters();
	
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

// StandardSubsystems.Properties
&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

#EndRegion

#EndRegion
