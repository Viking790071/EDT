#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillByWorkInProgress(FillingData, ConnectionKey = 1) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	ManufacturingOperationActivities.Ref AS BasisDocument,
	|	ManufacturingOperationActivities.Activity AS Operation,
	|	ManufacturingOperationActivities.ConnectionKey AS ConnectionKey,
	|	ManufacturingOperationActivities.Quantity AS OperationQuantity,
	|	ManufacturingOperationActivities.Output AS Output,
	|	ManufacturingOperationActivities.StandardTimeInUOM AS StandardTimeInUOM,
	|	ManufacturingOperationActivities.TimeUOM AS TimeUOM,
	|	ManufacturingOperationActivities.StandardTime AS StandardTime,
	|	ManufacturingOperation.Company AS Company,
	|	ManufacturingOperation.StructuralUnit AS StructuralUnit,
	|	ProductionSchedule.StartDate AS StartDatePlanned,
	|	ProductionSchedule.EndDate AS EndDatePlanned,
	|	MAX(ManufacturingActivitiesWorkCenterTypes.WorkcenterType) AS WorkcenterType
	|INTO TT_Operations
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		LEFT JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
	|		LEFT JOIN InformationRegister.ProductionSchedule AS ProductionSchedule
	|		ON ManufacturingOperationActivities.Ref = ProductionSchedule.Operation
	|			AND (ProductionSchedule.ScheduleState = 0)
	|		LEFT JOIN Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
	|		ON ManufacturingOperationActivities.Activity = ManufacturingActivitiesWorkCenterTypes.Ref
	|WHERE
	|	ManufacturingOperationActivities.Ref = &Ref
	|	AND ManufacturingOperationActivities.ConnectionKey = &ConnectionKey
	|
	|GROUP BY
	|	ManufacturingOperationActivities.Ref,
	|	ManufacturingOperationActivities.Activity,
	|	ManufacturingOperationActivities.ConnectionKey,
	|	ManufacturingOperationActivities.Quantity,
	|	ManufacturingOperationActivities.Output,
	|	ManufacturingOperationActivities.StandardTimeInUOM,
	|	ManufacturingOperationActivities.TimeUOM,
	|	ManufacturingOperationActivities.StandardTime,
	|	ManufacturingOperation.Company,
	|	ManufacturingOperation.StructuralUnit,
	|	ProductionSchedule.StartDate,
	|	ProductionSchedule.EndDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Operations.BasisDocument AS BasisDocument,
	|	TT_Operations.Operation AS Operation,
	|	TT_Operations.ConnectionKey AS ConnectionKey,
	|	TT_Operations.OperationQuantity AS OperationQuantity,
	|	TT_Operations.Output AS Output,
	|	TT_Operations.StandardTimeInUOM AS StandardTimeInUOM,
	|	TT_Operations.TimeUOM AS TimeUOM,
	|	TT_Operations.StandardTime AS StandardTime,
	|	TT_Operations.Company AS Company,
	|	TT_Operations.StructuralUnit AS StructuralUnit,
	|	TT_Operations.StartDatePlanned AS StartDatePlanned,
	|	TT_Operations.EndDatePlanned AS EndDatePlanned,
	|	TT_Operations.WorkcenterType AS WorkcenterType
	|FROM
	|	TT_Operations AS TT_Operations
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ManufacturingOperationInventory.Products AS Products,
	|	ManufacturingOperationInventory.Characteristic AS Characteristic,
	|	ManufacturingOperationInventory.Quantity AS Quantity,
	|	ManufacturingOperationInventory.MeasurementUnit AS MeasurementUnit
	|FROM
	|	TT_Operations AS TT_Operations
	|		INNER JOIN Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|		ON TT_Operations.BasisDocument = ManufacturingOperationInventory.Ref
	|			AND TT_Operations.ConnectionKey = ManufacturingOperationInventory.ActivityConnectionKey";
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("ConnectionKey", ConnectionKey);
	
	ResultsArray = Query.ExecuteBatch();
	
	Header = ResultsArray[1].Unload();
	
	If Header.Count() Then
		
		FillPropertyValues(ThisObject, Header[0]);
		Inventory.Load(ResultsArray[2].Unload());
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	Status = Enums.ProductionTaskStatuses.Open;
	
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.ManufacturingOperation")] = "FillByWorkInProgress";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	Documents.ProductionTask.InitializeDocumentData(Ref, AdditionalProperties);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectProductionAccomplishment(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	ReflectTasksForUpdatingStatuses(Cancel);
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	ReflectTasksForUpdatingStatuses(Cancel);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	FOUseCharacteristics = Constants.UseCharacteristics.Get();
	ComponentsList = "";
	For Each InventoryLine In Inventory Do
		
		If Not ValueIsFilled(InventoryLine.Products) Then
			Continue;
		EndIf;
		
		CharacteristicPresentation = "";
		If FOUseCharacteristics And ValueIsFilled(InventoryLine.Characteristic) Then
			CharacteristicPresentation = " (" + TrimAll(InventoryLine.Characteristic) + ")";
		EndIf;
		
		If ValueIsFilled(ComponentsList) Then
			ComponentsList = ComponentsList + Chars.LF;
		EndIf;
		
		ComponentsList = ComponentsList
			+ TrimAll(InventoryLine.Products)
			+ CharacteristicPresentation
			+ ", "
			+ InventoryLine.Quantity
			+ " "
			+ TrimAll(InventoryLine.MeasurementUnit);
		
	EndDo;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotWriteStatus") And Not DeletionMark Then
		
		InformationRegisters.ProductionTaskStatuses.SetProductionTaskStatus(Ref, Status);
		
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Status = Enums.ProductionTaskStatuses.Open;
	StartDate = Date(1, 1, 1);
	EndDate = Date(1, 1, 1);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ValueIsFilled(StartDatePlanned) And ValueIsFilled(EndDatePlanned)
		And StartDatePlanned > EndDatePlanned Then
		
		MessageText = NStr("en = 'Cannot save the changes. The scheduled start date cannot be later than the scheduled due date.'; ru = 'Не удалось сохранить изменения. Плановая дата начала не может быть больше плановой даты завершения.';pl = 'Nie można zapisać zmian. Zaplanowana data rozpoczęcia nie może być późniejsza niż zaplanowany termin.';es_ES = 'No se pueden guardar los cambios. La fecha de inicio programada no puede ser posterior a la fecha de vencimiento programada.';es_CO = 'No se pueden guardar los cambios. La fecha de inicio programada no puede ser posterior a la fecha de vencimiento programada.';tr = 'Değişiklikler kaydedilemiyor. Programlı başlangıç tarihi programlı bitiş tarihinden sonra olamaz.';it = 'Impossibile salvare le modifiche. La data di inizio pianificata non può essere successiva alla data di scadenza pianificata.';de = 'Fehler beim Speichern von Änderungen. Das geplante Startdatum darf nicht nach dem geplanten Fälligkeitstermin liegen.'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"StartDatePlanned",
			Cancel);
		
	EndIf;
	
	If ValueIsFilled(StartDate) And ValueIsFilled(EndDate)
		And StartDate > EndDate Then
		
		MessageText = NStr("en = 'Cannot save the changes. The actual start date cannot be later than the actual due date.'; ru = 'Не удалось сохранить изменения. Фактическая дата начала не может быть больше фактической даты завершения.';pl = 'Nie można zapisać zmian. Faktyczna data rozpoczęcia nie może być późniejsza niż faktyczny termin.';es_ES = 'No se pueden guardar los cambios. La fecha de inicio real no puede ser posterior a la fecha de vencimiento real.';es_CO = 'No se pueden guardar los cambios. La fecha de inicio real no puede ser posterior a la fecha de vencimiento real.';tr = 'Değişiklikler kaydedilemiyor. Gerçekleşen başlangıç tarihi gerçekleşen bitiş tarihinden sonra olamaz.';it = 'Impossibile salvare le modifiche. La data di inizio effettiva non può essere successiva alla data di scadenza effettiva.';de = 'Fehler beim Speichern von Änderungen. Das aktuelle Startdatum darf nicht nach dem aktuellen Fälligkeitstermin liegen.'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"StartDate",
			Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure ReflectTasksForUpdatingStatuses(Cancel)
	
	If AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
		
		If StructureTemporaryTables.Property("RegisterRecordsProductionAccomplishmentChange")
			And StructureTemporaryTables.RegisterRecordsProductionAccomplishmentChange Then
			
			If ValueIsFilled(BasisDocument) Then
				ProductionOrder = Common.ObjectAttributeValue(BasisDocument, "BasisDocument");
				
				If ValueIsFilled(ProductionOrder) Then
					DriveServer.ReflectTasksForUpdatingStatuses(ProductionOrder, Cancel);
					DriveServer.StartUpdateDocumentStatuses();
				EndIf;
			EndIf;
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
