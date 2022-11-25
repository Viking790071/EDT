
#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	SetColumnHeaders();
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		If Items.Find("EmployeeCode") <> Undefined Then		
			Items.EmployeeCode.Visible = False;		
		EndIf;
	EndIf;
	
	SetPriceTypesChoiceList();
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
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
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

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
// Receives a quotation from the server.
//
Function GetQuote(StructureData)
	
	StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
	StructureData.Insert("AmountIncludesVAT", StructureData.PriceKind.PriceIncludesVAT);
	StructureData.Insert("DocumentCurrency", StructureData.PriceKind.PriceCurrency);
	StructureData.Insert("Factor", 1);
	
	StructureData.Insert("Price", DriveServer.GetProductsPriceByPriceKind(StructureData));
	
	Return StructureData;
	
EndFunction

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Procedure CalculateTotal()

	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.Total = CurrentRow.MoDuration + CurrentRow.TuDuration + CurrentRow.WeDuration 
							+ CurrentRow.ThDuration + CurrentRow.FrDuration + CurrentRow.SaDuration  
							+ CurrentRow.SuDuration;
	CurrentRow.Amount = CurrentRow.Tariff * CurrentRow.Total;
		
EndProcedure

&AtClient
// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
Function CalculateDuration(BeginTime, EndTime)
	
	DurationInSeconds = EndTime - BeginTime;	
	Return Round(DurationInSeconds / 3600, 2);
	
EndFunction

&AtServer
// The procedure sets the headers of columns.
//
// Parameters:
//  No.
//
Procedure SetColumnHeaders()
	
	If Not ValueIsFilled(Object.DateFrom) Then
		Return;
	EndIf;
	
	WeekItems = GetWeekItemsCollection();
	
	AddToWeekItemsCollection(WeekItems, Items.GroupMo, Items.OperationsMonDuration);
	AddToWeekItemsCollection(WeekItems, Items.GroupTu, Items.OperationsTuDuration);
	AddToWeekItemsCollection(WeekItems, Items.GroupCp, Items.OperationsAverageDuration);
	AddToWeekItemsCollection(WeekItems, Items.GroupTh, Items.OperationsThDuration);
	AddToWeekItemsCollection(WeekItems, Items.GroupFr, Items.OperationsFrDuration);
	AddToWeekItemsCollection(WeekItems, Items.GroupSa, Items.OperationsSaDuration);
	AddToWeekItemsCollection(WeekItems, Items.GroupSu, Items.OperationsSuDuration);
	
	// Sort week days in order of regional settings
	If ValueIsFilled(Object.DateFrom) Then
		
		DateShift = WeekDay(Object.DateFrom);
		CurrentItemIndex = 1;
		ItemsToMove = New Array;
		
		For Each Row In WeekItems Do
			
			If DateShift = CurrentItemIndex Then
				Break;
			EndIf;
			
			ItemsToMove.Add(Row.GroupItem);
			CurrentItemIndex = CurrentItemIndex + 1;
			
		EndDo;
		
		For Each Item In ItemsToMove Do
			Items.Move(Item, Item.Parent);
		EndDo;
		
	EndIf;
	
	CurrentShift = 0;
	
	// Set appropriate names for titles
	For Each Item In Items.GroupWeek.ChildItems Do
		
		Row = WeekItems.Find(Item, "GroupItem");
		
		Row.DurationItem.Title = StrTemplate(NStr("en = '%1 %2'; ru = '%1 %2';pl = '%1 %2';es_ES = '%1 %2';es_CO = '%1 %2';tr = '%1 %2';it = '%1 %2';de = '%1 %2'"), 
			Format(Object.DateFrom + CurrentShift * 86400, "DF=ddd"), 
			Format(Object.DateFrom + CurrentShift * 86400, "DF=dd.MM"));
		
		CurrentShift = CurrentShift + 1;
		
	EndDo;
	
EndProcedure

&AtServer
// The procedure fills in a tabular section by planning data.
//
// Parameters:
//  No.
//
Procedure FillByPlanAtServer()

	Query = New Query("
	|SELECT ALLOWED
	|	WorkOrderWorks.WorkKind AS WorkKind,
	|	WorkOrderWorks.Customer AS Customer,
	|	WorkOrderWorks.Products AS Products,
	|	WorkOrderWorks.Characteristic AS Characteristic,
	|	WorkOrderWorks.Ref.PriceKind AS PriceKind,
	|	WorkOrderWorks.Price AS Price,
	|	WorkOrderWorks.DurationInHours AS Duration,
	|	WorkOrderWorks.BeginTime AS BeginTime,
	|	WorkOrderWorks.EndTime AS EndTime,
	|	WEEKDAY(WorkOrderWorks.Day) AS WeekDay
	|FROM
	|	Document.EmployeeTask.Works AS WorkOrderWorks,
	|	Constants AS Constants
	|WHERE
	|	WorkOrderWorks.Day BETWEEN &DateFrom AND &DateTo
	|	AND CASE
	|			WHEN Constants.AccountingBySubsidiaryCompany
	|				THEN Constants.ParentCompany = &Company
	|			ELSE WorkOrderWorks.Ref.Company = &Company
	|		END
	|	AND WorkOrderWorks.Ref.StructuralUnit = &StructuralUnit
	|	AND WorkOrderWorks.Ref.Employee = &Employee
	|	AND WorkOrderWorks.DurationInHours > 0
	|
	|ORDER BY
	|	WorkKind,
	|	Customer,
	|	Products,
	|	Characteristic,
	|	PriceKind,
	|	Price,
	|	WeekDay,
	|	BeginTime,
	|	EndTime
	|TOTALS BY
	|	WorkKind,
	|	Customer,
	|	Products,
	|	Characteristic,
	|	PriceKind,
	|	Price");	
	
	Query.SetParameter("Company", DriveServer.GetCompany(Object.Company));
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	Query.SetParameter("Employee", Object.Employee);
	Query.SetParameter("DateFrom", BegOfDay(Object.DateFrom));
	Query.SetParameter("DateTo", EndOfDay(Object.DateTo));
	
	SelectionWorkKind = Query.Execute().Select(QueryResultIteration.ByGroups, "WorkKind");
	
	WeekDays = New Map;
	WeekDays.Insert(1, "Mo");
	WeekDays.Insert(2, "Tu");
	WeekDays.Insert(3, "We");
	WeekDays.Insert(4, "Th");
	WeekDays.Insert(5, "Fr");
	WeekDays.Insert(6, "Sa");
	WeekDays.Insert(7, "Su");
	
	While SelectionWorkKind.Next() Do
		CustomerSelection = SelectionWorkKind.Select(QueryResultIteration.ByGroups, "Customer");
		While CustomerSelection.Next() Do
			SelectionProducts = CustomerSelection.Select(QueryResultIteration.ByGroups, "Products");
			While SelectionProducts.Next() Do
		    	SelectionCharacteristic = SelectionProducts.Select(QueryResultIteration.ByGroups, "Characteristic");
				While SelectionCharacteristic.Next() Do
		        	SelectionPriceKind = SelectionCharacteristic.Select(QueryResultIteration.ByGroups, "PriceKind");
					While SelectionPriceKind.Next() Do
		            	SelectionPrice = SelectionPriceKind.Select(QueryResultIteration.ByGroups, "Price");
						While SelectionPrice.Next() Do
							
							FirstIndex = Undefined;
							LastIndex = Undefined;
						
						 	Selection = SelectionPrice.Select();
							While Selection.Next() Do
							
								If FirstIndex = Undefined Then
									
									NewRow = Object.Operations.Add();
									NewRow.WorkKind 		= Selection.WorkKind;
									NewRow.Customer 		= Selection.Customer;
									NewRow.Products 	= Selection.Products;
									NewRow.Characteristic 	= Selection.Characteristic;
									NewRow.PriceKind 			= Selection.PriceKind;
									NewRow.Tariff 		= Selection.Price;
									NewRow[WeekDays.Get(Selection.WeekDay) + "Duration"] 	= Selection.Duration;
									NewRow[WeekDays.Get(Selection.WeekDay) + "BeginTime"] 	= Selection.BeginTime;
									NewRow[WeekDays.Get(Selection.WeekDay) + "EndTime"] 	= Selection.EndTime;
									NewRow.Total = Selection.Duration;
									NewRow.Amount = NewRow.Total * NewRow.Tariff;				
									
									FirstIndex = Object.Operations.IndexOf(NewRow);
									LastIndex = FirstIndex;
								
								Else
									
									StringFound = False;
									
									For Counter = FirstIndex To LastIndex Do
										
										CurrentRow = Object.Operations.Get(Counter);
										
										If CurrentRow[WeekDays.Get(Selection.WeekDay) + "Duration"] = 0 Then
										
											CurrentRow[WeekDays.Get(Selection.WeekDay) + "Duration"] = Selection.Duration;
											CurrentRow[WeekDays.Get(Selection.WeekDay) + "BeginTime"] = Selection.BeginTime;
											CurrentRow[WeekDays.Get(Selection.WeekDay) + "EndTime"] = Selection.EndTime;
											CurrentRow.Total = CurrentRow.Total + Selection.Duration;
											CurrentRow.Amount = CurrentRow.Total * CurrentRow.Tariff;
											
											StringFound = True;
											
											Break;
										
										EndIf;
									
									EndDo;
									
									If Not StringFound Then
									
										NewRow = Object.Operations.Add();
										NewRow.WorkKind 		= Selection.WorkKind;
										NewRow.Customer 		= Selection.Customer;
										NewRow.Products 	= Selection.Products;
										NewRow.Characteristic 	= Selection.Characteristic;
										NewRow.PriceKind 			= Selection.PriceKind;
										NewRow.Tariff 		= Selection.Price;
										NewRow[WeekDays.Get(Selection.WeekDay) + "Duration"] 	= Selection.Duration;
										NewRow[WeekDays.Get(Selection.WeekDay) + "BeginTime"] 	= Selection.BeginTime;
										NewRow[WeekDays.Get(Selection.WeekDay) + "EndTime"] 	= Selection.EndTime;
										NewRow.Total = Selection.Duration;
										NewRow.Amount = NewRow.Total * NewRow.Tariff;				
										
										LastIndex = Object.Operations.IndexOf(NewRow);	
									
									EndIf; 
									
								EndIf;
							
							EndDo;		
		 
						EndDo;
						
					EndDo;
					
				EndDo;
				
			EndDo;
			
		EndDo;
						
	EndDo;
	
EndProcedure

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
	
	SetPriceTypesChoiceList();
	
EndProcedure

&AtClient
// Procedure - OnChange event processor of DateFrom and DateUntil attribute.
//
Procedure DateFromOnChange(Item)
	
	Object.DateFrom = BegOfWeek(Object.DateFrom);
	Object.DateTo 	= ?(Object.DateFrom = Date(1,1,1),Date(1,1,1),EndOfWeek(Object.DateFrom));
	
	SetColumnHeaders();
	
EndProcedure

&AtClient
// Procedure - OnChange event processor of DateFrom and DateUntil attribute.
//
Procedure DateToOnChange(Item)
	
	Object.DateFrom = BegOfWeek(Object.DateTo);
	Object.DateTo 	= ?(Object.DateFrom = Date(1,1,1),Date(1,1,1),EndOfWeek(Object.DateTo));
	
	SetColumnHeaders();
	
EndProcedure

&AtClient
// Procedure - command handler FillInByPlan.
//
Procedure FillByPlan(Command)
	
	If Not ValueIsFilled(Object.Company) Then
        Message = New UserMessage();
		Message.Text = NStr("en = 'Company is not populated. Population is canceled.'; ru = 'Не заполнена организация! Заполнение отменено.';pl = 'Nie wypełniono pola organizacji. Wypełnienie anulowane.';es_ES = 'Empresa no está poblada. Población está cancelada.';es_CO = 'Empresa no está poblada. Población está cancelada.';tr = 'İş yeri doldurulmadı. Doldurma iptal edildi.';it = 'L''azienda non è compilata. Compilazione annullata.';de = 'Firma ist nicht ausgefüllt. Ausfüllung wird abgebrochen.'");
		Message.Field = "Object.Company";
		Message.Message();
		Return;
	EndIf;

	If Not ValueIsFilled(Object.StructuralUnit) Then
        Message = New UserMessage();
		Message.Text = NStr("en = 'Department is not populated. Population is canceled.'; ru = 'Не заполнено подразделение! Заполнение отменено.';pl = 'Nie wypełniono pola działu. Wypełnienie zostało anulowane.';es_ES = 'Departamento no está poblado. Población está cancelada.';es_CO = 'Departamento no está poblado. Población está cancelada.';tr = 'Bölüm doldurulmadı. Doldurma iptal edildi.';it = 'Reparto non compilato. Compilazione annullata.';de = 'Abteilung ist nicht ausgefüllt. Ausfüllung wird abgebrochen.'");
		Message.Field = "Object.StructuralUnit";
		Message.Message();
		Return;
	EndIf;

	If Not ValueIsFilled(Object.Employee) Then
        Message = New UserMessage();
		Message.Text = NStr("en = 'Employee is not selected. Population is canceled.'; ru = 'Не выбран сотрудник! Заполнение отменено.';pl = 'Nie wybrano pracownika. Wypełnienie anulowane.';es_ES = 'Empleado no está seleccionado. Población está cancelada.';es_CO = 'Empleado no está seleccionado. Población está cancelada.';tr = 'Çalışan seçilmedi. Doldurma iptal edildi.';it = 'Non è stato selezionato il dipendente! LA compilazione è annullata.';de = 'Mitarbeiter ist nicht ausgewählt. Ausfüllung wird abgebrochen.'");
		Message.Field = "Object.Employee";
		Message.Message();
		Return;
	EndIf;

	If Not ValueIsFilled(Object.DateFrom) Then
        Message = New UserMessage();
		Message.Text = NStr("en = 'Week start is not selected. Population is canceled.'; ru = 'Не выбрано начало недели! Заполнение отменено.';pl = 'Nie wybrano początku tygodnia. Wypełnienie anulowane.';es_ES = 'Inicio de la semana no está seleccionado. Población está cancelada.';es_CO = 'Inicio de la semana no está seleccionado. Población está cancelada.';tr = 'Hafta başlangıcı seçilmedi. Doldurma iptal edildi.';it = 'L''inizio settimana non è selezionato! La compilazione è annullata.';de = 'Wochenstart ist nicht ausgewählt. Ausfüllung wird abgebrochen.'");
		Message.Field = "Object.DateFrom";
		Message.Message();
		Return;
	EndIf;

	If Not ValueIsFilled(Object.DateTo) Then
        Message = New UserMessage();
		Message.Text = NStr("en = 'Week end is not selected. Population is canceled.'; ru = 'Не выбрано окончание недели! Заполнение отменено.';pl = 'Nie wybrano końca tygodnia. Wypełnienie anulowane.';es_ES = 'Fin de la semana no está seleccionado. Población está cancelada.';es_CO = 'Fin de la semana no está seleccionado. Población está cancelada.';tr = 'Hafta sonu seçilmedi. Doldurma iptal edildi.';it = 'Il fine settimana non è selezionato! La compilazione è annullata.';de = 'Wochenende ist nicht ausgewählt. Ausfüllung wird abgebrochen.'");
		Message.Field = "Object.DateTo";
		Message.Message();
		Return;
	EndIf;

	If Object.Operations.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillInByPlanEnd", ThisObject), NStr("en = 'Tabular section of the document will be cleared. Continue?'; ru = 'Табличная часть документа будет очищена! Продолжить?';pl = 'Sekcja tabelaryczna dokumentu zostanie wyczyszczona. Kontynuować?';es_ES = 'Sección tabular del documento se limpiará. ¿Continuar?';es_CO = 'Sección tabular del documento se limpiará. ¿Continuar?';tr = 'Belgenin tablo bölümü temizlenecek. Devam edilsin mi?';it = 'La sezione tabellare del documento verrà cancellata. Continuare?';de = 'Der Tabellenabschnitt des Dokuments wird gelöscht. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;
	
	FillInByPlanFragment();
EndProcedure

&AtClient
Procedure FillInByPlanEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillInByPlanFragment();

EndProcedure

&AtClient
Procedure FillInByPlanFragment()
	
	Object.Operations.Clear();
	FillByPlanAtServer();
	SetColumnHeaders();
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

#Region EventHandlersOfThePartsTabularSectionAttributes

&AtClient
// Procedure - OnChange event handler of WorkKind attribute of Operations tabular section.
//
Procedure OperationsWorksKindOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", 		Object.Company);
	StructureData.Insert("Products", 	CurrentRow.WorkKind);	
	StructureData.Insert("PriceKind", 			CurrentRow.PriceKind);	
	StructureData.Insert("ProcessingDate", 	DocumentDate);
	CurrentRow.Tariff = GetQuote(StructureData).Price;
	CurrentRow.Amount = CurrentRow.Tariff * CurrentRow.Total;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of Tariff attribute of Operations tabular section.
//
Procedure OperationsTariffOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.Amount = CurrentRow.Tariff * CurrentRow.Total;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the Amount attribute of the Operations tabular section.
//
Procedure OperationsAmountOnChange(Item)
	
	CurrentRow = Items.Operations.CurrentData;
	CurrentRow.Tariff = ?(CurrentRow.Total = 0, 0, CurrentRow.Amount / CurrentRow.Total);
	
EndProcedure

&AtClient
// Procedure - SelectionStart event handler of Comment attribute of Operations tabular section.
//
Procedure OperationsCommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Operations.CurrentData;
	FormParameters = New Structure("Text, Title", CurrentData.Comment, "Comment edit");  
	ReturnComment = Undefined;
  
	OpenForm("CommonForm.TextEdit", FormParameters,,,,, New NotifyDescription("OperationsCommentStartChoiceEnd", ThisObject, New Structure("CurrentData", CurrentData))); 
	
EndProcedure

&AtClient
Procedure OperationsCommentStartChoiceEnd(Result, AdditionalParameters) Export
    
    CurrentData = AdditionalParameters.CurrentData;
    
    
    ReturnComment = Result;
    
    If TypeOf(ReturnComment) = Type("String") Then
        
        If CurrentData.Comment <> ReturnComment Then
            Modified = True;
        EndIf;
        
        CurrentData.Comment = ReturnComment;
        
    EndIf;

EndProcedure

&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsMoDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.MoDuration * 3600;	
	CurrentData.MoEndTime = CurrentData.MoBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.MoBeginTime < DurationInSeconds Then	
		CurrentData.MoEndTime = '00010101235959';
		CurrentData.MoDuration = CalculateDuration(CurrentData.MoBeginTime, CurrentData.MoEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsMoWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.MoDuration * 3600;	
	CurrentData.MoEndTime = CurrentData.MoBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.MoBeginTime < DurationInSeconds Then	
		CurrentData.MoEndTime = '00010101235959';
		CurrentData.MoDuration = CalculateDuration(CurrentData.MoBeginTime, CurrentData.MoEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsMoByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.MoBeginTime > CurrentData.MoEndTime Then
		CurrentData.MoBeginTime = CurrentData.MoEndTime;
	EndIf; 
	
	CurrentData.MoDuration = CalculateDuration(CurrentData.MoBeginTime, CurrentData.MoEndTime);
	CalculateTotal(); 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsTuDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.TuDuration * 3600;	
	CurrentData.TuEndTime = CurrentData.TuBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.TuBeginTime < DurationInSeconds Then	
		CurrentData.TuEndTime = '00010101235959';
		CurrentData.TuDuration = CalculateDuration(CurrentData.TuBeginTime, CurrentData.TuEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsTuFromOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.TuDuration * 3600;	
	CurrentData.TuEndTime = CurrentData.TuBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.TuBeginTime < DurationInSeconds Then	
		CurrentData.TuEndTime = '00010101235959';
		CurrentData.TuDuration = CalculateDuration(CurrentData.TuBeginTime, CurrentData.TuEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsTuToOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.TuBeginTime > CurrentData.TuEndTime Then
		CurrentData.TuBeginTime = CurrentData.TuEndTime;
	EndIf; 
	
	CurrentData.TuDuration = CalculateDuration(CurrentData.TuBeginTime, CurrentData.TuEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsWeDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.WeDuration * 3600;	
	CurrentData.WeEndTime = CurrentData.WeBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.WeBeginTime < DurationInSeconds Then	
		CurrentData.WeEndTime = '00010101235959';
		CurrentData.WeDuration = CalculateDuration(CurrentData.WeBeginTime, CurrentData.WeEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsWeWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.WeDuration * 3600;	
	CurrentData.WeEndTime = CurrentData.WeBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.WeBeginTime < DurationInSeconds Then	
		CurrentData.WeEndTime = '00010101235959';
		CurrentData.WeDuration = CalculateDuration(CurrentData.WeBeginTime, CurrentData.WeEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsWeByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.WeBeginTime > CurrentData.WeEndTime Then
		CurrentData.WeBeginTime = CurrentData.WeEndTime;
	EndIf; 
	
	CurrentData.WeDuration = CalculateDuration(CurrentData.WeBeginTime, CurrentData.WeEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsThDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.ThDuration * 3600;	
	CurrentData.ThEndTime = CurrentData.ThBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.ThBeginTime < DurationInSeconds Then	
		CurrentData.ThEndTime = '00010101235959';
		CurrentData.ThDuration = CalculateDuration(CurrentData.ThBeginTime, CurrentData.ThEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsThWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.ThDuration * 3600;	
	CurrentData.ThEndTime = CurrentData.ThBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.ThBeginTime < DurationInSeconds Then	
		CurrentData.ThEndTime = '00010101235959';
		CurrentData.ThDuration = CalculateDuration(CurrentData.ThBeginTime, CurrentData.ThEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsThByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.ThBeginTime > CurrentData.ThEndTime Then
		CurrentData.ThBeginTime = CurrentData.ThEndTime;
	EndIf; 
	
	CurrentData.ThDuration = CalculateDuration(CurrentData.ThBeginTime, CurrentData.ThEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsFrDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.FrDuration * 3600;	
	CurrentData.FrEndTime = CurrentData.FrBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.FrBeginTime < DurationInSeconds Then	
		CurrentData.FrEndTime = '00010101235959';
		CurrentData.FrDuration = CalculateDuration(CurrentData.FrBeginTime, CurrentData.FrEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsFrWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.FrDuration * 3600;	
	CurrentData.FrEndTime = CurrentData.FrBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.FrBeginTime < DurationInSeconds Then	
		CurrentData.FrEndTime = '00010101235959';
		CurrentData.FrDuration = CalculateDuration(CurrentData.FrBeginTime, CurrentData.FrEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsFrByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.FrBeginTime > CurrentData.FrEndTime Then
		CurrentData.FrBeginTime = CurrentData.FrEndTime;
	EndIf; 
	
	CurrentData.FrDuration = CalculateDuration(CurrentData.FrBeginTime, CurrentData.FrEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsSaDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.SaDuration * 3600;	
	CurrentData.SaEndTime = CurrentData.SaBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.SaBeginTime < DurationInSeconds Then	
		CurrentData.SaEndTime = '00010101235959';
		CurrentData.SaDuration = CalculateDuration(CurrentData.SaBeginTime, CurrentData.SaEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsSaWithOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.SaDuration * 3600;	
	CurrentData.SaEndTime = CurrentData.SaBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.SaBeginTime < DurationInSeconds Then	
		CurrentData.SaEndTime = '00010101235959';
		CurrentData.SaDuration = CalculateDuration(CurrentData.SaBeginTime, CurrentData.SaEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsSaByOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.SaBeginTime > CurrentData.SaEndTime Then
		CurrentData.SaBeginTime = CurrentData.SaEndTime;
	EndIf; 
	
	CurrentData.SaDuration = CalculateDuration(CurrentData.SaBeginTime, CurrentData.SaEndTime);
	CalculateTotal(); 
	
EndProcedure
&AtClient
// Procedure - OnChange event handler of Duration attribute of Operations tabular section.
//
Procedure OperationsSuDurationOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.SuDuration * 3600;	
	CurrentData.SuEndTime = CurrentData.SuBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.SuBeginTime < DurationInSeconds Then	
		CurrentData.SuEndTime = '00010101235959';
		CurrentData.SuDuration = CalculateDuration(CurrentData.SuBeginTime, CurrentData.SuEndTime);		
	EndIf;
	
	CalculateTotal();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of BeginTime attribute of Operations tabular section.
//
Procedure OperationsSuFromOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	
	DurationInSeconds = CurrentData.SuDuration * 3600;	
	CurrentData.SuEndTime = CurrentData.SuBeginTime + DurationInSeconds;
	                                       
	If '00010101235959' - CurrentData.SuBeginTime < DurationInSeconds Then	
		CurrentData.SuEndTime = '00010101235959';
		CurrentData.SuDuration = CalculateDuration(CurrentData.SuBeginTime, CurrentData.SuEndTime);		
		CalculateTotal(); 
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of EndTime attribute of Operations tabular section.
//
Procedure OperationsSuToOnChange(Item)
	
	CurrentData = Items.Operations.CurrentData;
	If CurrentData.SuBeginTime > CurrentData.SuEndTime Then
		CurrentData.SuBeginTime = CurrentData.SuEndTime;
	EndIf; 
	
	CurrentData.SuDuration = CalculateDuration(CurrentData.SuBeginTime, CurrentData.SuEndTime);
	CalculateTotal(); 
	
EndProcedure

&AtClient
// Procedure - event handler ChoiceProcessing of attribute Customer.
//
Procedure OperationsConsumerChoiceProcessingChoice(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = Type("CatalogRef.CounterpartyContracts") Then
	
		StandardProcessing = False;
		
		SelectedContract = Undefined;

		
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceFormWithCounterparty",,,,,, New NotifyDescription("OperationsCustomerChoiceChoiceProcessingEnd", ThisObject));
	
	EndIf;	
	
EndProcedure

&AtClient
Procedure OperationsCustomerChoiceChoiceProcessingEnd(Result, AdditionalParameters) Export
    
    SelectedContract = Result;
    
    If TypeOf(SelectedContract) = Type("CatalogRef.CounterpartyContracts")Then
        Items.Operations.CurrentData.Customer = SelectedContract;
    EndIf;

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

#EndRegion

#Region Private

&AtServer
Procedure SetPriceTypesChoiceList()

	WorkWithForm.SetChoiceParametersByCompany(Object.Company, ThisForm, "OperationsPriceKind");
	
EndProcedure

&AtServerNoContext
Procedure AddToWeekItemsCollection(Table, GroupItem, DurationItem)
	
	NewRow = Table.Add();
	NewRow.GroupItem = GroupItem;
	NewRow.DurationItem = DurationItem;
	
EndProcedure

&AtServerNoContext
Function GetWeekItemsCollection()
	
	WeekItems = New ValueTable;
	WeekItems.Columns.Add("GroupItem");
	WeekItems.Columns.Add("DurationItem");
	
	Return WeekItems;
	
EndFunction

#EndRegion

