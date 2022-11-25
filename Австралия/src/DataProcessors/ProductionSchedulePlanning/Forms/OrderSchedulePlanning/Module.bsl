#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("ProductionOrder", ProductionOrder) Then
		
		Raise NStr("en = 'Data processor is not intended for direct usage.'; ru = 'Обработка не предназначена для непосредственного использования.';pl = 'Procesor danych nie jest przeznaczony do bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanım için uygun değildir.';it = 'L''elaborazione dati non è indicata per l''uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'");
		
	EndIf;
	
	FormManagement();
	
	ReadProductionOrderData();
	FillGroupOnSchedule(0);
	RefreshScheduleData();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Exit Then
		Cancel = True;
		Return;
	EndIf;
	
	If ScheduleIsPlanned Then
		Cancel = True;
		ShowQuestionSaveChanges();
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshProductionOrderQueue"
		And ValueIsFilled(Parameter)
		And Parameter.Find(ProductionOrder) <> Undefined Then
		
		FormManagement();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersStages

&AtClient
Procedure StagesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	WIP = Items.Stages.RowData(SelectedRow).WIP;
	ShowValue(, WIP);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Plan(Command)
	
	NotifyDescription = New NotifyDescription("PlanningSettingsEnd", ThisObject);
	FormParameters = New Structure;
	FormParameters.Insert("ProductionOrders", CommonClientServer.ValueInArray(ProductionOrder));
	OpenForm("DataProcessor.ProductionSchedulePlanning.Form.PlanningSettings", FormParameters,,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure Save(Command)
	
	If ScheduleIsPlanned Then
		
		SaveAtClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StagesGanttChart(Command)
	
	ChartParameters = New Structure;
	ChartParameters.Insert("ProductionOrder", ProductionOrder);
	ChartParameters.Insert("ScheduleState", ?(ScheduleIsPlanned, 1, 0));
	OpenForm("Report.ProductionStagesChart.Form", ChartParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FormManagement()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ManufacturingOperation.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.BasisDocument = &ProductionOrder
	|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Completed)
	|	AND ManufacturingOperation.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperation.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.BasisDocument = &ProductionOrder
	|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.InProcess)
	|	AND ManufacturingOperation.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionSchedule.Operation AS Operation
	|FROM
	|	InformationRegister.ProductionSchedule AS ProductionSchedule
	|WHERE
	|	ProductionSchedule.ProductionOrder = &ProductionOrder
	|	AND ProductionSchedule.ScheduleState = 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperation.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.BasisDocument = &ProductionOrder
	|	AND ManufacturingOperation.Posted";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.ExecuteBatch();
	
	If Not QueryResult[0].IsEmpty() Then
		
		Items.FormPlan.Enabled = False;
		Items.FormSave.Enabled = False;
		
		UserInfo = NStr("en = 'One or more operations of the Production order are completed and can not be scheduled.'; ru = 'Одна или несколько операций заказа на производство завершены и не могут быть запланированы.';pl = 'Jedna lub więcej operacji Zlecenie produkcyjne są zakończone i nie mogą być zaplanowane.';es_ES = 'Una o varias operaciones de la Orden de producción han finalizado y no se pueden programar.';es_CO = 'Una o varias operaciones de la Orden de producción han finalizado y no se pueden programar.';tr = 'Üretim emrinin bir veya birkaç işlemi tamamlandığından programlanamaz.';it = 'Una o più operazioni dell''Ordine di produzione sono completate e non possono essere programmate.';de = 'Eine oder mehr Operationen des Produktionsauftrags sind abgeschlossen und können nicht geplant werden.'");
		
		If QueryResult[0].Unload().Count() = QueryResult[3].Unload().Count() Then
			UserInfo = NStr("en = 'Operations of the Production order are completed and can not be scheduled or rescheduled.'; ru = 'Операции заказа на производство завершены и не могут быть запланированы или перепланированы.';pl = 'Operacje Zlecenie produkcyjne są zakończone nie mogą być zaplanowane lub przesunięte.';es_ES = 'Las operaciones de la Orden de producción han finalizado y no pueden ser programadas o reprogramadas.';es_CO = 'Las operaciones de la Orden de producción han finalizado y no pueden ser programadas o reprogramadas.';tr = 'Üretim emrinin işlemleri tamamlandığından (yeniden) programlanamaz.';it = 'Le operazioni dell''Ordine di produzione sono completate e non possono essere programmate o riprogrammate.';de = 'Operationen des Produktionsauftrags sind abgeschlossen und können nicht geplant oder neu geplant werden.'");
		ElsIf QueryResult[2].IsEmpty() Then
			UserInfo = NStr("en = 'One or more operations of the Production order are completed and can not be rescheduled.'; ru = 'Одна или несколько операций заказа на производство завершены и не могут быть перепланированы.';pl = 'Jedna lub więcej operacji Zlecenie produkcyjne są zakończone i nie mogą być przesunięte.';es_ES = 'Una o varias operaciones de la Orden de producción han finalizado y no se pueden reprogramar.';es_CO = 'Una o varias operaciones de la Orden de producción han finalizado y no se pueden reprogramar.';tr = 'Üretim emrinin bir veya birkaç işlemi tamamlandığından yeniden programlanamaz.';it = 'Una o più operazioni dell''Ordine di produzione sono completate e non possono essere riprogrammate.';de = 'Eine oder mehr Operationen des Produktionsauftrags sind abgeschlossen und können nicht neu geplant werden.'");
		EndIf;
		
		Items.UserInformation.Visible = True;
		Items.UserInformation.Title = UserInfo;
		
	ElsIf Not QueryResult[1].IsEmpty() Then
		
		Items.FormPlan.Enabled = False;
		Items.FormSave.Enabled = False;
		
		UserInfo = NStr("en = 'One or more operations of the Production order are in progress and can not be scheduled.'; ru = 'Одна или несколько операций заказа на производство в работе и не могут быть запланированы.';pl = 'Jedna lub więcej operacji Zlecenie produkcyjne są w toku i nie mogą być zaplanowane.';es_ES = 'Una o varias operaciones de la Orden de producción están en progreso y no se pueden programar.';es_CO = 'Una o varias operaciones de la Orden de producción están en progreso y no se pueden programar.';tr = 'Üretim emrinin bir veya birkaç işlemi devam ettiğinden programlanamaz.';it = 'Una o più operazioni dell''Ordine di produzione sono in lavorazione e non possono essere programmate.';de = 'Eine oder mehr Operationen des Produktionsauftrags sind in Bearbeitung und können nicht geplant werden.'");
		If Not QueryResult[2].IsEmpty() Then
			UserInfo = NStr("en = 'One or more operations of the Production order are in progress and can not be rescheduled. To clear scheduling, please, clear Include in production planning chechbox in the Production order.'; ru = 'Одна или несколько операций заказа на производство в работе и не могут быть перепланированы. Чтобы очистить планирование, снимите флажок ""Включить в планирование производства"" в заказе на производство.';pl = 'Jedna lub więcej operacji Zlecenie produkcyjne są w toku i nie mogą być przesunięte. Aby wyczyścić planowanie, wyczyść pole wyboru Uwzględnij w planowaniu produkcji w Zleceniu produkcyjnym.';es_ES = 'Una o más operaciones de la Orden de producción están en progreso y no se pueden reprogramar. Para borrar la programación, por favor, desmarque la casilla de verificación Incluir en la planificación de la producción en la Orden de producción.';es_CO = 'Una o más operaciones de la Orden de producción están en progreso y no se pueden reprogramar. Para borrar la programación, por favor, desmarque la casilla de verificación Incluir en la planificación de la producción en la Orden de producción.';tr = 'Üretim emrinin bir veya birkaç işlemi devam ettiğinden yeniden programlanamaz. Programı silmek için lütfen Üretim emrindeki Üretim planlamasına dahil et onay kutusunu temizleyin.';it = 'Una o più operazioni dell''Ordine di produzione sono in lavorazione e non possono essere riprogrammate. Per cancellare la programmazione, deselezionare la casella di controllo Includere in pianificazione di produzione nell''Ordine di produzione.';de = 'Eine oder mehr Operationen des Produktionsauftrags sind in Bearbeitung und können nicht geplant werden. Bitte deaktivieren Sie im Produktionsauftrag das Kontrollkästchen In Produktionsplanung einschließen um die Planung zu entleeren.'");
		EndIf;
		
		Items.UserInformation.Visible = True;
		Items.UserInformation.Title = UserInfo;
		
	Else
		
		Items.FormPlan.Enabled = True;
		Items.FormSave.Enabled = True;
		Items.UserInformation.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadProductionOrderData()
	
	OrderData = Common.ObjectAttributesValues(ProductionOrder, "Start, Finish, Number, Date");
	
	Start = OrderData.Start;
	Finish = OrderData.Finish;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Production schedule for order %1 dated %2'; ru = 'График производства для заказа %1 от %2';pl = 'Harmonogram produkcji dla zaówienia %1 z dnia %2';es_ES = 'Programa de producción de la orden %1 fechado %2';es_CO = 'Programa de producción de la orden %1 fechado %2';tr = '%2 tarihli %1 emri için üretim takvimi';it = 'Pianificazione di produzione per l''ordine %1 datato %2';de = 'Produktionsplanung für den Auftrag  %1 vom %2'"),
		ObjectPrefixationClientServer.GetNumberForPrinting(OrderData.Number, True, True),
		Format(OrderData.Date, "DLF=D"));
	
EndProcedure

&AtServer
Procedure RefreshScheduleData()
	
	SetStagesTableParameters();
	
EndProcedure

&AtServer
Procedure SetStagesTableParameters(OpenWIPState = 0)
	
	Stages.Parameters.SetParameterValue("ProductionOrder", ProductionOrder);
	Stages.Parameters.SetParameterValue("OpenWIPState", OpenWIPState);
	
EndProcedure

&AtServer
Procedure FillGroupOnSchedule(ScheduleState)
	
	ProductionSchedule = InformationRegisters.ProductionSchedule.CreateRecordSet();
	ProductionSchedule.Filter.ProductionOrder.Set(ProductionOrder);
	ProductionSchedule.Filter.ScheduleState.Set(ScheduleState);
	
	ProductionSchedule.Read();
	ProductionScheduleTable = ProductionSchedule.Unload();
	
	ScheduleStartDT = ProductionPlanningServer.MinDateInArray(ProductionScheduleTable.UnloadColumn("StartDate"));
	ScheduleFinishDT= ProductionPlanningServer.MaxDateInArray(ProductionScheduleTable.UnloadColumn("EndDate"));
	
	ScheduleStart = ScheduleStartDT;
	ScheduleFinish = ScheduleFinishDT;
	
	ScheduleDelayInSeconds = ScheduleFinishDT - EndOfDay(Finish);
	If ScheduleDelayInSeconds > 0 Then
		ScheduleDelayInHours = Round(ScheduleDelayInSeconds / 3600, 0, RoundMode.Round15as20);
		ScheduleDelay = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 h.'; ru = '%1 ч.';pl = '%1 g.';es_ES = '%1 horas';es_CO = '%1 horas';tr = '%1 saat.';it = '%1 h.';de = '%1 Stunden.'"), ScheduleDelayInHours);
	Else
		ScheduleDelay = "";
	EndIf;
	
	ScheduleDurationInSeconds = ScheduleFinishDT - ScheduleStartDT;
	If ScheduleDurationInSeconds > 0 Then
		ScheduleDurationInHours = Round(ScheduleDurationInSeconds / 3600, 0, RoundMode.Round15as20);
		ScheduleDuration = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 h.'; ru = '%1 ч.';pl = '%1 g.';es_ES = '%1 horas';es_CO = '%1 horas';tr = '%1 saat.';it = '%1 h.';de = '%1 Stunden.'"), ScheduleDurationInHours);
	Else
		ScheduleDuration = "";
	EndIf;
	
	ScheduleNetTimeInMins = ScheduleNetTime();
	If ScheduleNetTimeInMins > 0 Then
		ScheduleNetTimeInHours = Round(ScheduleNetTimeInMins / 60, 0, RoundMode.Round15as20);
		ScheduleNetTime = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 h.'; ru = '%1 ч.';pl = '%1 g.';es_ES = '%1 horas';es_CO = '%1 horas';tr = '%1 saat.';it = '%1 h.';de = '%1 Stunden.'"), ScheduleNetTimeInHours);
	Else
		ScheduleNetTime = "";
	EndIf;
	
	Modified = (ScheduleState = 1);
	
EndProcedure

&AtServer
Function ScheduleNetTime()
	
	NetTime = 0;
	Query = New Query;
	
	If ScheduleIsPlanned Then
		
		Query.Text = 
		"SELECT
		|	ManufacturingOperation.Ref AS Ref
		|INTO TT_WIPs
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	ManufacturingOperation.Posted
		|	AND ManufacturingOperation.BasisDocument = &ProductionOrder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkcentersAvailabilityPreliminary.StartDate AS StartDate,
		|	WorkcentersAvailabilityPreliminary.Operation AS WIP,
		|	WorkcentersAvailabilityPreliminary.EndDate AS EndDate
		|INTO TT_WCTLevel
		|FROM
		|	InformationRegister.WorkcentersAvailabilityPreliminary AS WorkcentersAvailabilityPreliminary,
		|	TT_WIPs AS TT_WIPs
		|
		|GROUP BY
		|	WorkcentersAvailabilityPreliminary.StartDate,
		|	WorkcentersAvailabilityPreliminary.EndDate,
		|	WorkcentersAvailabilityPreliminary.Operation
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	ProductionSchedule.StartDate AS StartDate,
		|	ProductionSchedule.EndDate AS EndDate
		|INTO TT_NoWCTLevel
		|FROM
		|	InformationRegister.ProductionSchedule AS ProductionSchedule
		|		INNER JOIN TT_WIPs AS TT_WIPs
		|		ON ProductionSchedule.Operation = TT_WIPs.Ref
		|		LEFT JOIN TT_WCTLevel AS TT_WCTLevel
		|		ON ProductionSchedule.Operation = TT_WCTLevel.WIP
		|WHERE
		|	TT_WCTLevel.WIP IS NULL
		|	AND ProductionSchedule.ScheduleState = 1
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_WCTLevel.StartDate AS StartDate,
		|	TT_WCTLevel.EndDate AS EndDate
		|INTO TT_WCTIntervals
		|FROM
		|	TT_WCTLevel AS TT_WCTLevel
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_WCTIntervals.StartDate AS StartDate,
		|	TT_WCTIntervals.EndDate AS EndDate
		|INTO TT_AllIntervals
		|FROM
		|	TT_WCTIntervals AS TT_WCTIntervals
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	TT_NoWCTLevel.StartDate,
		|	TT_NoWCTLevel.EndDate
		|FROM
		|	TT_NoWCTLevel AS TT_NoWCTLevel
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_AllIntervals.StartDate AS StartDate,
		|	MAX(TT_AllIntervals.EndDate) AS EndDate
		|INTO TT_Collapse1
		|FROM
		|	TT_AllIntervals AS TT_AllIntervals
		|
		|GROUP BY
		|	TT_AllIntervals.StartDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(TT_Collapse1.StartDate) AS StartDate,
		|	TT_Collapse1.EndDate AS EndDate
		|INTO TT_Collapse2
		|FROM
		|	TT_Collapse1 AS TT_Collapse1
		|
		|GROUP BY
		|	TT_Collapse1.EndDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(CASE
		|			WHEN TT_Collapse2.StartDate < ISNULL(TT_Collapse21.StartDate, DATETIME(3999, 12, 31))
		|				THEN TT_Collapse2.StartDate
		|			ELSE TT_Collapse21.StartDate
		|		END) AS StartDate,
		|	CASE
		|		WHEN TT_Collapse2.EndDate > ISNULL(TT_Collapse21.EndDate, DATETIME(1, 1, 1))
		|			THEN TT_Collapse2.EndDate
		|		ELSE TT_Collapse21.EndDate
		|	END AS EndDate
		|INTO TT_Collapse3
		|FROM
		|	TT_Collapse2 AS TT_Collapse2
		|		LEFT JOIN TT_Collapse2 AS TT_Collapse21
		|		ON TT_Collapse2.EndDate > TT_Collapse21.StartDate
		|			AND TT_Collapse2.EndDate < TT_Collapse21.EndDate
		|
		|GROUP BY
		|	CASE
		|		WHEN TT_Collapse2.EndDate > ISNULL(TT_Collapse21.EndDate, DATETIME(1, 1, 1))
		|			THEN TT_Collapse2.EndDate
		|		ELSE TT_Collapse21.EndDate
		|	END
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Collapse3.StartDate AS StartDate,
		|	MAX(TT_Collapse3.EndDate) AS EndDate
		|INTO TT_Collapse4
		|FROM
		|	TT_Collapse3 AS TT_Collapse3
		|
		|GROUP BY
		|	TT_Collapse3.StartDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SUM(DATEDIFF(TT_Collapse4.StartDate, TT_Collapse4.EndDate, MINUTE)) AS NetTime
		|FROM
		|	TT_Collapse4 AS TT_Collapse4";
		
	Else
		
		Query.Text = 
		"SELECT
		|	ManufacturingOperation.Ref AS Ref
		|INTO TT_WIPs
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	ManufacturingOperation.Posted
		|	AND ManufacturingOperation.BasisDocument = &ProductionOrder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkcentersAvailability.Period AS StartDate,
		|	WorkcentersAvailability.Recorder AS WIP,
		|	CASE
		|		WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Week)
		|			THEN DATEADD(WorkcentersAvailability.Period, WEEK, 1)
		|		WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Day)
		|			THEN DATEADD(WorkcentersAvailability.Period, DAY, 1)
		|		WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Hour)
		|			THEN DATEADD(WorkcentersAvailability.Period, HOUR, 1)
		|		WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Minute)
		|			THEN DATEADD(WorkcentersAvailability.Period, MINUTE, BusinessUnits.PlanningIntervalDuration)
		|	END AS EndDate
		|INTO TT_WCTLevel
		|FROM
		|	AccumulationRegister.WorkcentersAvailability AS WorkcentersAvailability
		|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
		|		ON WorkcentersAvailability.WorkcenterType.BusinessUnit = BusinessUnits.Ref
		|		INNER JOIN TT_WIPs AS TT_WIPs
		|		ON WorkcentersAvailability.Recorder = TT_WIPs.Ref
		|
		|GROUP BY
		|	WorkcentersAvailability.Period,
		|	WorkcentersAvailability.Recorder,
		|	CASE
		|		WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Week)
		|			THEN DATEADD(WorkcentersAvailability.Period, WEEK, 1)
		|		WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Day)
		|			THEN DATEADD(WorkcentersAvailability.Period, DAY, 1)
		|		WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Hour)
		|			THEN DATEADD(WorkcentersAvailability.Period, HOUR, 1)
		|		WHEN BusinessUnits.PlanningInterval = VALUE(Enum.PlanningIntervals.Minute)
		|			THEN DATEADD(WorkcentersAvailability.Period, MINUTE, BusinessUnits.PlanningIntervalDuration)
		|	END
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	ProductionSchedule.StartDate AS StartDate,
		|	ProductionSchedule.EndDate AS EndDate
		|INTO TT_NoWCTLevel
		|FROM
		|	InformationRegister.ProductionSchedule AS ProductionSchedule
		|		INNER JOIN TT_WIPs AS TT_WIPs
		|		ON ProductionSchedule.Operation = TT_WIPs.Ref
		|		LEFT JOIN TT_WCTLevel AS TT_WCTLevel
		|		ON ProductionSchedule.Operation = TT_WCTLevel.WIP
		|WHERE
		|	TT_WCTLevel.WIP IS NULL
		|	AND ProductionSchedule.ScheduleState = 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_WCTLevel.StartDate AS StartDate,
		|	TT_WCTLevel.EndDate AS EndDate
		|INTO TT_WCTIntervals
		|FROM
		|	TT_WCTLevel AS TT_WCTLevel
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_WCTIntervals.StartDate AS StartDate,
		|	TT_WCTIntervals.EndDate AS EndDate
		|INTO TT_AllIntervals
		|FROM
		|	TT_WCTIntervals AS TT_WCTIntervals
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	TT_NoWCTLevel.StartDate,
		|	TT_NoWCTLevel.EndDate
		|FROM
		|	TT_NoWCTLevel AS TT_NoWCTLevel
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_AllIntervals.StartDate AS StartDate,
		|	MAX(TT_AllIntervals.EndDate) AS EndDate
		|INTO TT_Collapse1
		|FROM
		|	TT_AllIntervals AS TT_AllIntervals
		|
		|GROUP BY
		|	TT_AllIntervals.StartDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(TT_Collapse1.StartDate) AS StartDate,
		|	TT_Collapse1.EndDate AS EndDate
		|INTO TT_Collapse2
		|FROM
		|	TT_Collapse1 AS TT_Collapse1
		|
		|GROUP BY
		|	TT_Collapse1.EndDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(CASE
		|			WHEN TT_Collapse2.StartDate < ISNULL(TT_Collapse21.StartDate, DATETIME(3999, 12, 31))
		|				THEN TT_Collapse2.StartDate
		|			ELSE TT_Collapse21.StartDate
		|		END) AS StartDate,
		|	CASE
		|		WHEN TT_Collapse2.EndDate > ISNULL(TT_Collapse21.EndDate, DATETIME(1, 1, 1))
		|			THEN TT_Collapse2.EndDate
		|		ELSE TT_Collapse21.EndDate
		|	END AS EndDate
		|INTO TT_Collapse3
		|FROM
		|	TT_Collapse2 AS TT_Collapse2
		|		LEFT JOIN TT_Collapse2 AS TT_Collapse21
		|		ON TT_Collapse2.EndDate > TT_Collapse21.StartDate
		|			AND TT_Collapse2.EndDate < TT_Collapse21.EndDate
		|
		|GROUP BY
		|	CASE
		|		WHEN TT_Collapse2.EndDate > ISNULL(TT_Collapse21.EndDate, DATETIME(1, 1, 1))
		|			THEN TT_Collapse2.EndDate
		|		ELSE TT_Collapse21.EndDate
		|	END
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Collapse3.StartDate AS StartDate,
		|	MAX(TT_Collapse3.EndDate) AS EndDate
		|INTO TT_Collapse4
		|FROM
		|	TT_Collapse3 AS TT_Collapse3
		|
		|GROUP BY
		|	TT_Collapse3.StartDate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SUM(DATEDIFF(TT_Collapse4.StartDate, TT_Collapse4.EndDate, MINUTE)) AS NetTime
		|FROM
		|	TT_Collapse4 AS TT_Collapse4";
		
	EndIf;
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		If ValueIsFilled(SelectionDetailRecords.NetTime) Then
			NetTime = NetTime + SelectionDetailRecords.NetTime;
		EndIf;
		
	EndIf;
	
	Return NetTime;
	
EndFunction

#Region Planning

&AtClient
Procedure PlanningSettingsEnd(PlanningSettings, AdditionalParameters) Export
	
	If PlanningSettings <> Undefined Then
		
		BackgroungJobName = PlanningJobName();
		BackgroundJobDescription = NStr("en = 'Production schedule planning.'; ru = 'Планирование графика производства.';pl = 'Planowanie harmonogramu produkcji.';es_ES = 'Planificación del programa de producción.';es_CO = 'Planificación del programa de producción.';tr = 'Üretim takvimi planlaması.';it = 'Pianificazione della produzione';de = 'Produktionsplanung'");
		
		PlanTheQueueByTheCurrentOne = PlanningSettings.PlanTheQueueByTheCurrentOne;
		PlanningSettings.Insert("ProductionOrder", ProductionOrder);
		Result = PlanInBackgroungMode(PlanningSettings);
		
		If Result.Status = "Completed" Or Result.Status = "Error" Then
			
			CheckBackgroungJobCompletion(Result, Undefined);
			
		Else
			
			StartBackgroungJobWaiting(Result);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function PlanInBackgroungMode(PlanningSettings)
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitForCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Production schedule planning for order'; ru = 'Планирование графика производства для заказа';pl = 'Planowanie harmonogramu produkcji dla zamówienia';es_ES = 'Planificación del programa de producción para el pedido';es_CO = 'Planificación del programa de producción para el pedido';tr = 'Sipariş için üretim takvimi planlaması';it = 'Pianificazione di produzione per l''ordine';de = 'Produktionsplanung für Auftrag'");
	
	OperationResult = TimeConsumingOperations.ExecuteInBackground(
		"ProductionPlanningServer.MainPlanOneOrder",
		PlanningSettings,
		ExecutionParameters);
	
	Return OperationResult;
	
EndFunction

&AtServer
Procedure PlanningWasFinished()
	
	SetStagesTableParameters(1);
	FillGroupOnSchedule(1);
	
EndProcedure

&AtClientAtServerNoContext
Function PlanningJobName()
	
	Return "PlanSchedule";
	
EndFunction

#EndRegion

#Region Saving

&AtClient
Procedure SaveAtClient()
	
	BackgroungJobName = SavingJobName();
	BackgroundJobDescription = NStr("en = 'Production schedule saving.'; ru = 'Сохранение графика производства.';pl = 'Zapisywanie harmonogramu produkcji.';es_ES = 'Guardar el programa de producción.';es_CO = 'Guardar el programa de producción.';tr = 'Üretim takvimi kaydetme işlemi.';it = 'Salvataggio pianificazione di produzione.';de = 'Speichern von Produktionsplan.'");
	
	SavingSettings = New Structure;
	SavingSettings.Insert("Orders", Orders.UnloadValues());
	SavingSettings.Insert("OrdersToExclude", Orders.UnloadValues());
	SavingSettings.Insert("WIPs", WIPs.UnloadValues());
	SavingSettings.Insert("JobNumber", JobNumber);
	SavingSettings.Insert("PlanTheQueueByTheCurrentOne", PlanTheQueueByTheCurrentOne);
	
	Result = SaveInBackgroungMode(SavingSettings);
	
	If Result.Status = "Completed" Or Result.Status = "Error" Then
		
		CheckBackgroungJobCompletion(Result, Undefined);
		
	Else
		
		StartBackgroungJobWaiting(Result);
		
	EndIf;
	
EndProcedure

&AtServer
Function SaveInBackgroungMode(PlanningSettings)
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitForCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = BackgroundJobDescription;
	
	OperationResult = TimeConsumingOperations.ExecuteInBackground(
		"ProductionPlanningServer.MainSaveOneOrder",
		PlanningSettings,
		ExecutionParameters);
	
	Return OperationResult;
	
EndFunction

&AtServer
Procedure SavingWasFinished()
	
	SetStagesTableParameters(0);
	FillGroupOnSchedule(0);
	
EndProcedure

&AtClientAtServerNoContext
Function SavingJobName()
	
	Return "SaveSchedule";
	
EndFunction

#EndRegion

#Region CancelSaving

&AtClient
Procedure ShowQuestionSaveChanges()
	
	Notify = New NotifyDescription("QuestionSaveChangesEnd", ThisObject);
	QuestionText = NStr("en = 'Data has been changed. Save the changes?'; ru = 'Данные изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Zapisać zmiany?';es_ES = 'Se han cambiado los datos. ¿Guardar los cambios?';es_CO = 'Se han cambiado los datos. ¿Guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikler kaydedilsin mi?';it = 'I dati sono stati modificati. Salvare le modifiche?';de = 'Die Daten sind geändert. Änderungen speichern?'");
	
	ShowQueryBox(Notify, QuestionText,  QuestionDialogMode.YesNoCancel);
	
EndProcedure

&AtClient
Procedure QuestionSaveChangesEnd(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		SaveAtClient();
		
	ElsIf Answer = DialogReturnCode.No Then
		
		CancelSaving();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CancelSaving()
	
	BackgroungJobName = CancelJobName();
	BackgroundJobDescription = NStr("en = 'Clear preliminary production schedule.'; ru = 'Очистить предварительный график производства.';pl = 'Oczyść wstępny harmonogram produkcji.';es_ES = 'Borrar el programa de producción preliminar.';es_CO = 'Borrar el programa de producción preliminar.';tr = 'Ön üretim takvimini temizle.';it = 'Eliminare pianificazione di produzione preliminare.';de = 'Vorläufigen Produktionsplan löschen.'");
	
	CancelSettings = New Structure;
	CancelSettings.Insert("Orders", Orders.UnloadValues());
	CancelSettings.Insert("WIPs", WIPs.UnloadValues());
	
	Result = CancelInBackgroungMode(CancelSettings);
	
	If Result.Status = "Completed" Or Result.Status = "Error" Then
		
		CheckBackgroungJobCompletion(Result, Undefined);
		
	Else
		
		StartBackgroungJobWaiting(Result);
		
	EndIf;
	
EndProcedure

&AtServer
Function CancelInBackgroungMode(PlanningSettings)
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitForCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = BackgroundJobDescription;
	
	OperationResult = TimeConsumingOperations.ExecuteInBackground(
		"ProductionPlanningServer.MainCancelOneOrder",
		PlanningSettings,
		ExecutionParameters);
	
	Return OperationResult;
	
EndFunction

&AtServer
Procedure CancelWasFinished()
	
	SetStagesTableParameters(0);
	FillGroupOnSchedule(0);
	
EndProcedure

&AtClientAtServerNoContext
Function CancelJobName()
	
	Return "CancelSchedule";
	
EndFunction

#EndRegion

#Region TimeConsumingOperations

&AtClient
Procedure StartBackgroungJobWaiting(TimeConsumingOperation)
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(Undefined);
	IdleParameters.MessageText = BackgroundJobDescription;
	IdleParameters.OutputIdleWindow = True;
	
	CompletionNotification = New NotifyDescription("CheckBackgroungJobCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	
EndProcedure

&AtClient
Procedure CheckBackgroungJobCompletion(Result, ExecuteParameters) Export
	
	If Result = Undefined Or Result.Status = "Canceled" Then
		
		Return;
		
	ElsIf Result.Status = "Error" Then
		
		CommonClientServer.MessageToUser(Result.BriefErrorPresentation);
		
	ElsIf Result.Status = "Completed" Then
		
		If BackgroungJobName = PlanningJobName() Then
			
			ResultStructure = GetFromTempStorage(Result.ResultAddress);
			
			If ResultStructure.PlannedSuccessfully Then
				
				ScheduleIsPlanned = True;
				Orders.LoadValues(ResultStructure.Orders);
				WIPs.LoadValues(ResultStructure.WIPs);
				JobNumber = ResultStructure.JobNumber;
				
				If MainOrderWasPlanned(ResultStructure.ListOfErrorsToShow) Then
					
					PlanningWasFinished();
					Items.Stages.Refresh();
					
				EndIf;
				
				ShowPlanningErrors(ResultStructure.ListOfErrorsToShow);
				
				CommonClientServer.MessageToUser(NStr("en = 'Planned successfully.'; ru = 'Успешно запланировано.';pl = 'Zaplanowano pomyślnie.';es_ES = 'Planificación exitosa.';es_CO = 'Planificación exitosa.';tr = 'Başarıyla planlandı.';it = 'Pianificato con successo.';de = 'Planung erfolgreich.'"));
				
			ElsIf ResultStructure.ErrorsInEventLog Then
				
				ShowMessageErrorsInEventLog();
				
			ElsIf ResultStructure.ErrorsToShow Then
				
				ShowPlanningErrors(ResultStructure.ListOfErrorsToShow);
				
			EndIf;
			
		ElsIf BackgroungJobName = SavingJobName() Then
			
			ResultStructure = GetFromTempStorage(Result.ResultAddress);
			
			If ResultStructure.ErrorsInEventLog Then
				
				ShowMessageErrorsInEventLog();
				
			Else
				
				ScheduleIsPlanned = False;
				CancelWasFinished();
				Items.Stages.Refresh();
				Notify("RefreshProductionOrderQueue", WIPs.UnloadValues());
				
			EndIf;
			
		ElsIf BackgroungJobName = CancelJobName() Then
			
			ResultStructure = GetFromTempStorage(Result.ResultAddress);
			
			If ResultStructure.ErrorsInEventLog Then
				
				ScheduleIsPlanned = False;
				ShowMessageErrorsInEventLog();
				
			Else
				
				ScheduleIsPlanned = False;
				SavingWasFinished();
				Items.Stages.Refresh();
				
			EndIf;
			
			Close();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Function MainOrderWasPlanned(ListOfErrorsToShow)
	
	ErrorTextNothingToPlan = ProductionPlanningClientServer.ErrorTextNothingToPlan(ProductionOrder);
	
	Return (ListOfErrorsToShow.Find(ErrorTextNothingToPlan) = Undefined);
	
EndFunction

&AtClient
Procedure ShowPlanningErrors(ListOfErrorsToShow)
	
	For Each ErrorText In ListOfErrorsToShow Do
		
		CommonClientServer.MessageToUser(ErrorText);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ShowMessageErrorsInEventLog()
	
	ErrorText = NStr("en = 'Something went wrong while planning. Technical info was written to the event log.
		|Proceed to the event log?'; 
		|ru = 'При планировании произошла неизвестная ошибка. Технические сведения записаны в журнал регистрации.
		|Перейти в журнал регистрации?';
		|pl = 'Coś poszło nie tak podczas planowania. Informacje techniczne zostały zapisane do dziennika zmian.
		|Przejść do dziennika wydarzeń?';
		|es_ES = 'Ocurrió un error en la planificación. La información técnica fue grabada en el registro de eventos. 
		|¿Proceder al registro de eventos?';
		|es_CO = 'Ocurrió un error en la planificación. La información técnica fue grabada en el registro de eventos. 
		|¿Proceder al registro de eventos?';
		|tr = 'Planlama sırasında hata oluştu. Teknik bilgiler olay günlüğüne yazıldı.
		|Olay günlüğüne gitmek istiyor musunuz?';
		|it = 'Pianificazione di produzione non riuscita. I dettagli sono salvati nel registro degli eventi.
		|Aprire registro degli eventi?';
		|de = 'Fehlentwicklung beim Planen. Technische Informationen sind im Ereignisprotokoll  eingetragen.
		|Zu Ereignisprotokoll gehen?'");
	Notification = New NotifyDescription("ShowEventLogWhenErrorOccurred", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No, NStr("en = 'Production planning'; ru = 'Планирование производства';pl = 'Planowanie produkcji';es_ES = 'Planificación de producción';es_CO = 'Planificación de producción';tr = 'Üretim planlaması';it = 'Pianificazione produzione';de = 'Produktionsplanung'"));
	
EndProcedure

&AtClient
Procedure ShowEventLogWhenErrorOccurred(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", NStr("en = 'Production schedule.Planning'; ru = 'Производственный график.Планирование';pl = 'Harmonogram produkcji.Planowanie';es_ES = 'Production schedule.Planning';es_CO = 'Production schedule.Planning';tr = 'Planlama takvimi.Planlama';it = 'Pianificazione di produzione.Pianificazione';de = 'Produktionsplan.Planung'", CommonClientServer.DefaultLanguageCode()));
		OpenForm("DataProcessor.EventLog.Form", Filter);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion