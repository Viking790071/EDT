#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region PredeterminedProceduresEventsHandlers

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		
		If DeletionMark AND Acts Then
			Acts = False;
		EndIf;
		
		IsClarificationByProducts = ?(RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByProducts, ProductsGroupsPriceGroups.Count() > 0, False);
		IsClarificationByProductsCategories = ?(RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByProductsCategories, ProductsGroupsPriceGroups.Count() > 0, False);
		IsClarificationByPriceGroups = ?(RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByPriceGroups, ProductsGroupsPriceGroups.Count() > 0, False);
		IsClarificationByProductsSegments = ?(RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByProductsSegments, ProductsGroupsPriceGroups.Count() > 0, False);
		
		ThereIsSchedule = False;
		For Each CurrentTimetableString In TimeByDaysOfWeek Do
			If CurrentTimetableString.Selected Then
				ThereIsSchedule = True;
				Break;
			EndIf;
		EndDo;
		
		IsRestrictionOnRecipientsCounterparties = DiscountRecipientsCounterparties.Count() > 0;
		IsRestrictionOnRecipientsCounterpartySegments = DiscountRecipientsCounterpartySegments.Count() > 0;
		IsRestrictionByRecipientsWarehouses = DiscountRecipientsWarehouses.Count() > 0;
		
		If RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByProducts Then
			Query = New Query;
			Query.Text = 
				"SELECT
				|	AutomaticDiscountsProductsGroupsPriceGroups.ValueClarification
				|INTO TU_AutomaticDiscountsProductsGroupsPriceGroups
				|FROM
				|	&ProductsGroupsPriceGroups AS AutomaticDiscountsProductsGroupsPriceGroups
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT TOP 1
				|	TU_AutomaticDiscountsProductsGroupsPriceGroups.ValueClarification
				|FROM
				|	TU_AutomaticDiscountsProductsGroupsPriceGroups AS TU_AutomaticDiscountsProductsGroupsPriceGroups
				|WHERE
				|	TU_AutomaticDiscountsProductsGroupsPriceGroups.ValueClarification.IsFolder";
			
			Query.SetParameter("ByProducts", RestrictionByProductsVariant);
			Query.SetParameter("ProductsGroupsPriceGroups", ProductsGroupsPriceGroups.Unload());
			
			Result = Query.Execute();
			
			ThereAreFoldersToBeClarifiedByProducts = Not Result.IsEmpty();
		Else
			ThereAreFoldersToBeClarifiedByProducts = False;
		EndIf;
		
		// To remove rows without conditions.
		MRowsToDelete = New Array;
		For Each CurrentCondition In ConditionsOfAssignment Do
			If CurrentCondition.AssignmentCondition.IsEmpty() Then
				MRowsToDelete.Add(CurrentCondition);
			EndIf;
		EndDo;
		
		For Each RemovedRow In MRowsToDelete Do
			ConditionsOfAssignment.Delete(RemovedRow);
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsFolder Then
		Return;
	EndIf;
	
	NoncheckableAttributeArray = New Array;
	
	If AssignmentMethod <> Enums.DiscountValueType.Amount Then
		NoncheckableAttributeArray.Add("AssignmentCurrency");
	EndIf;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

// Procedure - FillingProcessor event handler.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Not IsFolder Then
		AssignmentCurrency = DriveReUse.GetFunctionalCurrency();
	Else
		SharedUsageVariant = Constants.DefaultDiscountsApplyingRule.Get();
	EndIf;
	
EndProcedure

Procedure UpdateInformationInServiceInformationRegister(Cancel)
	
	SetPrivilegedMode(True);
	
	// Update information in service information register used to optimize
	// number of cases which require to calculate automatic discounts.
	RecordManager = InformationRegisters.ServiceAutomaticDiscounts.CreateRecordManager();
	
	Block = New DataLock;
	LockItem = Block.Add();
	LockItem.Region = "InformationRegister.PeriodClosingDates";
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		RecordManager.Read();
			
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.ConditionsOfAssignment AS AutomaticDiscountsAssignmentCondition
			|WHERE
			|	AutomaticDiscountsAssignmentCondition.AssignmentCondition.AssignmentCondition = &ForOneTimeSalesVolume
			|	AND AutomaticDiscountsAssignmentCondition.AssignmentCondition.UseRestrictionCriterionForSalesVolume = &Amount
			|	AND AutomaticDiscountsAssignmentCondition.Ref.Acts
			|	AND NOT AutomaticDiscountsAssignmentCondition.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.ConditionsOfAssignment AS AutomaticDiscountsAssignmentCondition
			|WHERE
			|	AutomaticDiscountsAssignmentCondition.AssignmentCondition.AssignmentCondition = &ForKitPurchase
			|	AND AutomaticDiscountsAssignmentCondition.Ref.Acts
			|	AND NOT AutomaticDiscountsAssignmentCondition.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.DiscountRecipientsCounterparties AS AutomaticDiscountsDiscountRecipientsCounterparties
			|WHERE
			|	AutomaticDiscountsDiscountRecipientsCounterparties.Ref.Acts
			|	AND NOT AutomaticDiscountsDiscountRecipientsCounterparties.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.DiscountRecipientsCounterpartySegments AS AutomaticDiscountTypesDiscountRecipientsCounterpartySegments
			|WHERE
			|	AutomaticDiscountTypesDiscountRecipientsCounterpartySegments.Ref.Acts
			|	AND NOT AutomaticDiscountTypesDiscountRecipientsCounterpartySegments.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.DiscountRecipientsWarehouses AS AutomaticDiscountsDiscountRecipientsWarehouses
			|WHERE
			|	AutomaticDiscountsDiscountRecipientsWarehouses.Ref.Acts
			|	AND NOT AutomaticDiscountsDiscountRecipientsWarehouses.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.TimeByDaysOfWeek AS AutomaticDiscountsTimeByWeekDays
			|WHERE
			|	AutomaticDiscountsTimeByWeekDays.Ref.Acts
			|	AND NOT AutomaticDiscountsTimeByWeekDays.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes AS AutomaticDiscountTypes
			|WHERE
			|	NOT AutomaticDiscountTypes.DeletionMark
			|	AND AutomaticDiscountTypes.Acts";
		
		Query.SetParameter("ForOneTimeSalesVolume", Enums.DiscountCondition.ForOneTimeSalesVolume);
		Query.SetParameter("ForKitPurchase", Enums.DiscountCondition.ForKitPurchase);
		Query.SetParameter("Amount", Enums.DiscountSalesAmountLimit.Amount);
		Query.SetParameter("Ref", Ref);
		
		MResults = Query.ExecuteBatch();
		
		// There is a discount depending on the amount.
		Selection = MResults[0].Select();
		RecordManager.AmountDependingDiscountsAvailable = Selection.Next();
		
		// There is a discount for complete purchase.
		Selection = MResults[1].Select();
		RecordManager.PurchaseSetDependingDiscountsAvailable = Selection.Next();
		
		// There are discounts with restriction by counterparties.
		Selection = MResults[2].Select();
		RecordManager.CounterpartyRecipientDiscountsAvailable = Selection.Next();
		
		// There are discounts with restriction by segments.
		Selection = MResults[3].Select();
		RecordManager.SegmentRecipientDiscountsAvailable = Selection.Next();
		
		// There are discounts with restriction by warehouses.
		Selection = MResults[4].Select();
		RecordManager.WarehouseRecipientDiscountsAvailable = Selection.Next();
		
		// There are discounts with timetable.
		Selection = MResults[5].Select();
		RecordManager.ScheduleDiscountsAvailable = Selection.Next();
		
		RecordManager.Write();
		
		// There are applicable discounts.
		Selection = MResults[6].Select();
		Constants.ThereAreAutomaticDiscounts.Set(Selection.Next());
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		ErrorPresentation = BriefErrorDescription(ErrorInfo());
	EndTry;
	
	SetPrivilegedMode(False);
	
	WriteLogEvent(
			NStr("en = 'Automatic discounts.Service information on automatic discounts'; ru = 'Автоматические скидки. Служебная информация по автоматическим скидкам';pl = 'Rabaty automatyczne.Informacje serwisowe o automatycznych rabatach';es_ES = 'Descuentos automáticos.Información de servicio sobre descuentos automáticos';es_CO = 'Descuentos automáticos.Información de servicio sobre descuentos automáticos';tr = 'Otomatik indirimler. Otomatik indirimlerle ilgili servis bilgileri';it = 'Sconti automatici. Informazioni di servizio sugli sconti automatici';de = 'Automatische Rabatte.Serviceinformationen über automatische Rabatte'",
			     CommonClientServer.DefaultLanguageCode()),
			?(Cancel, EventLogLevel.Error, EventLogLevel.Information),
			,
			,
			ErrorPresentation,
			EventLogEntryTransactionMode.Independent);
	
	If Cancel Then
		Raise
			NStr("en = 'Failed to record service information on automatic discounts and extra charges.
			     |Details in the event log.'; 
			     |ru = 'Не удалось записать служебную информацию по автоматическим скидкам, наценкам.
			     |Подробности в журнале регистрации.';
			     |pl = 'Nie można zarejestrować informacji o usłudze w przypadku automatycznych rabatów i dodatkowych opłat.
			     |Szczegóły w rejestrze wydarzeń.';
			     |es_ES = 'Fallado para grabar la información de servicio sobre descuentos automáticos y extra cargas.
			     |Detalles en el registro de eventos.';
			     |es_CO = 'Fallado para grabar la información de servicio sobre descuentos automáticos y extra cargas.
			     |Detalles en el registro de eventos.';
			     |tr = 'Otomatik indirimler ve ek ücretler hakkında servis bilgileri kaydedilemedi.
			     |Ayrıntılar olay günlüğünde.';
			     |it = 'Impossibile registrare il servizio informazioni automatico sconti e le spese extra.
			     |Dettagli nel registro eventi.';
			     |de = 'Fehler beim Aufzeichnen von Serviceinformationen zu automatischen Rabatten und zusätzlichen Gebühren.
			     |Details im Ereignisprotokoll.'");
	EndIf;
	
EndProcedure

// Procedure - event handler OnWrite.
//
Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		If Not (AdditionalProperties.Property("RegisterServiceAutomaticDiscounts")
			AND AdditionalProperties.RegisterServiceAutomaticDiscounts = False) Then
			UpdateInformationInServiceInformationRegister(Cancel);
		EndIf;
		
		Return;
	EndIf;
	
	UpdateInformationInServiceInformationRegister(Cancel);
	
EndProcedure

#EndRegion

#EndIf