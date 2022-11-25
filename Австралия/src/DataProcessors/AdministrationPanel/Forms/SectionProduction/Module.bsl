
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "ConstantsSet.UseProductionSubsystem" Or AttributePathToData = "" Then
		
		If ConstantsSet.UseProductionSubsystem Then
			
			CommonClientServer.SetFormItemProperty(Items, "SettingDefaultProductionOrdersByStatus",	"Enabled", Not ConstantsSet.UseProductionOrderStatuses);
			CommonClientServer.SetFormItemProperty(Items, "CatalogProductionOrderStates", 			"Enabled", ConstantsSet.UseProductionOrderStatuses);
			
			If Not IsBlankString(AttributePathToData) Then
				
				Constants.UseOperationsManagement.Set(True);
				ConstantsSet.UseOperationsManagement = True;
				
			EndIf;
			
		Else
			
			If Not IsBlankString(AttributePathToData) Then
				
				Constants.UseSubcontractingManufacturing.Set(False);
				ConstantsSet.UseSubcontractingManufacturing = False;
				
				Constants.UseOperationsManagement.Set(False);
				ConstantsSet.UseOperationsManagement = False;
				
				Constants.UseOperationsManagement.Set(False);
				ConstantsSet.UseOperationsManagement = False;
				
				Constants.UseResourcesWorkloadPlanning.Set(False);
				ConstantsSet.UseResourcesWorkloadPlanning = False;
				
				Constants.UseProductionPlanning.Set(False);
				ConstantsSet.UseProductionPlanning = False;
				
				Constants.UseProductionOrderStatuses.Set(False);
				ConstantsSet.UseProductionOrderStatuses = False;
				
				Constants.UseProductionTask.Set(False);
				ConstantsSet.UseProductionTask = False;
				
			EndIf;
			
		EndIf;
		
		CommonClientServer.SetFormItemProperty(Items, "SettingsProductionOrder",	"Enabled", ConstantsSet.UseProductionSubsystem);
		CommonClientServer.SetFormItemProperty(Items, "Subcontracting",				"Enabled", ConstantsSet.UseProductionSubsystem);
		CommonClientServer.SetFormItemProperty(Items, "SettingsOthers", 			"Enabled", ConstantsSet.UseProductionSubsystem);
		CommonClientServer.SetFormItemProperty(Items, "ResourcesLoadSettings", 		"Enabled", ConstantsSet.UseProductionSubsystem);
		CommonClientServer.SetFormItemProperty(Items, "RowProductionPlanning",		"Enabled", ConstantsSet.UseResourcesWorkloadPlanning);
		CommonClientServer.SetFormItemProperty(Items, "SettingsUseProductionTask",	"Enabled", ConstantsSet.UseProductionSubsystem);
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseProductionOrderStatuses" Or AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "SettingDefaultProductionOrdersByStatus",	"Enabled", Not ConstantsSet.UseProductionOrderStatuses);
		CommonClientServer.SetFormItemProperty(Items, "CatalogProductionOrderStates", 			"Enabled", ConstantsSet.UseProductionOrderStatuses);
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseResourcesWorkloadPlanning" Or AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "RowProductionPlanning", "Enabled", ConstantsSet.UseResourcesWorkloadPlanning);
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseProductionPlanning" Or AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "PlanningHorizon", "Enabled", ConstantsSet.UseProductionPlanning);
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseResourcesWorkloadPlanning" Or AttributePathToData = "" Then
		
		CommonClientServer.SetFormItemProperty(Items, "DataProcessorWorkCentersWorkplaceOpen", "Enabled", ConstantsSet.UseResourcesWorkloadPlanning);
		
	EndIf;
	
	If AttributePathToData = "" Then
		
		UseSubcontractorOrderIssuedValue = Constants.CanReceiveSubcontractingServices.Get();
		
		CommonClientServer.SetFormItemProperty(Items,
			"UseSubcontractorManufacturers",
			"Enabled",
			Not UseSubcontractorOrderIssuedValue);
		
		CommonClientServer.SetFormItemProperty(Items,
			"UseSubcontractorManufacturers",
			"Visible",
			ConstantsSet.UseSubcontractorManufacturers);
			
		// Additionally
		CommonClientServer.SetFormItemProperty(Items, 
			"SettingsProcessingOfTollingFO", 
			"Visible", 
			ConstantsSet.UseBatches And ConstantsSet.UseSubcontractingManufacturing And HasSubcontractingSalesOrders());
		
	EndIf;
	
EndProcedure

&AtServer
Function HasSubcontractingSalesOrders()
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	SalesOrder.Ref AS Ref
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source",
			"Record_ConstantsSet",
			New Structure("Value", ConstantValue),
			ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
	If ConstantName = "UseProductionTask" Then
		Documents.ManufacturingOperation.UpdateProductionAccomplishmentRecords();
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UseProductionSubsystem" Then
		
		ConstantsSet.UseProductionSubsystem = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseProductionOrderStatuses" Then
		
		ConstantsSet.UseProductionOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.ProductionOrdersInProgressStatus" Then
		
		ConstantsSet.ProductionOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.ProductionOrdersCompletionStatus" Then
		
		ConstantsSet.ProductionOrdersCompletionStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSubcontractingManufacturing" Then
		
		ConstantsSet.UseSubcontractingManufacturing = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseOperationsManagement" Then
		
		ConstantsSet.UseOperationsManagement = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseResourcesWorkloadPlanning" Then 
		
		ConstantsSet.UseResourcesWorkloadPlanning = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseProductionPlanning" Then
		
		ConstantsSet.UseProductionPlanning = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseProductionTask" Then
		
		ConstantsSet.UseProductionTask = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSubcontractorOrderIssuedStatuses" Then
		
		ConstantsSet.UseSubcontractorOrderIssuedStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.SubcontractorOrderIssuedInProgressStatus" Then
		
		ConstantsSet.SubcontractorOrderIssuedInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.SubcontractorOrderIssuedCompletionStatus" Then
		
		ConstantsSet.SubcontractorOrderIssuedCompletionStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.CanReceiveSubcontractingServices" Then
		
		ConstantsSet.CanReceiveSubcontractingServices = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.MaxNumberOfBOMLevels" Then
		
		ConstantsSet.MaxNumberOfBOMLevels = CurrentValue;
		
	EndIf;
	
EndProcedure

// The removal control procedure of the Use production by registers option.
//
&AtServer
Function CheckRecordsByProductionSubsystemRegisters()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Inventory.Company AS Company
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	(Inventory.GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
	|			OR Inventory.GLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))";
	
	Result = Query.Execute();
	
	// Inventory Register.
	If Not Result.IsEmpty() Then
		ErrorText = NStr("en = 'There are records in the ""Inventory"" register where the GL account is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют движения по регистру ""Запасы"", где счет учета имеет тип ""Косвенные затраты"" или ""Незавершенное производство""! Снятие флага ""Производство"" запрещено!';pl = 'Istnieją wpisy w rejestrze ""Ewidencja księgowa"", w których konto księgowe ma typ ""Koszty pośrednie"" lub ""Niezakończona produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay grabaciones en el registro ""Inventario"" donde la cuenta del libro mayor del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay grabaciones en el registro ""Inventario"" donde la cuenta del libro mayor del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Muhasebe hesabının ""Dolaylı maliyetler"" veya ""Bitmemiş üretim"" türünde olduğu ""Stok"" kaydında kayıtlar bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nel database delle informazioni ci sono movimenti sul registro ""Scorte"", dove il conto è del tipo ""Costi indiretti"" o ""Produzione non finita""! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'Im Register ""Bestand"" gibt es Datensätze, bei denen das Hauptbuch-Konto vom Typ ""Indirekte Kosten"" oder ""Unfertige Produktion"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

// The removal control procedure of the Use production option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseSubsystemProduction()
	
	ErrorText = "";
	
	NewProduction = ConstantsSet.UseProductionSubsystem;
	
	If Not NewProduction Then
	
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	ProductionOrder.Ref
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	Production.Ref
		|FROM
		|	Document.Production AS Production
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	Production.Ref
		|FROM
		|	Document.Manufacturing AS Production
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	DockCostAllocation.Ref
		|FROM
		|	Document.CostAllocation AS DockCostAllocation
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	SalesOrder.Ref
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|WHERE
		|	SalesOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	JobSheet.Ref
		|FROM
		|	Document.JobSheet AS JobSheet
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	IntraWarehouseTransfer.Ref
		|FROM
		|	Document.IntraWarehouseTransfer AS IntraWarehouseTransfer
		|WHERE
		|	IntraWarehouseTransfer.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	InventoryTransfer.Ref
		|FROM
		|	Document.InventoryTransfer AS InventoryTransfer
		|WHERE
		|	((InventoryTransfer.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|				OR InventoryTransfer.StructuralUnitPayee.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department))
		|				AND InventoryTransfer.OperationKind = VALUE(Enum.OperationTypesInventoryTransfer.Transfer)
		|			OR InventoryTransfer.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	OpeningBalanceEntryFixedAssets.Ref
		|FROM
		|	Document.OpeningBalanceEntry.FixedAssets AS OpeningBalanceEntryFixedAssets
		|WHERE
		|	(OpeningBalanceEntryFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR OpeningBalanceEntryFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	OpeningBalanceEntryInventory.Ref
		|FROM
		|	Document.OpeningBalanceEntry.Inventory AS OpeningBalanceEntryInventory
		|WHERE
		|	OpeningBalanceEntryInventory.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	EnteringOpeningBalancesDirectCost.Ref
		|FROM
		|	Document.OpeningBalanceEntry.DirectCost AS EnteringOpeningBalancesDirectCost
		|WHERE
		|	EnteringOpeningBalancesDirectCost.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	FixedAssetRecognitionFixedAssets.Ref
		|FROM
		|	Document.FixedAssetRecognition.FixedAssets AS FixedAssetRecognitionFixedAssets
		|WHERE
		|	(FixedAssetRecognitionFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR FixedAssetRecognitionFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	InventoryIncrease.Ref
		|FROM
		|	Document.InventoryIncrease AS InventoryIncrease
		|WHERE
		|	InventoryIncrease.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	BudgetBalance.Ref
		|FROM
		|	Document.Budget.Balance AS BudgetBalance
		|WHERE
		|	(BudgetBalance.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR BudgetBalance.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	BudgetIndirectExpenses.Ref
		|FROM
		|	Document.Budget.IndirectExpenses AS BudgetIndirectExpenses
		|WHERE
		|	(BudgetIndirectExpenses.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR BudgetIndirectExpenses.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
		|			OR BudgetIndirectExpenses.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR BudgetIndirectExpenses.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	BudgetDirectCost.Ref
		|FROM
		|	Document.Budget.DirectCost AS BudgetDirectCost
		|WHERE
		|	(BudgetDirectCost.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR BudgetDirectCost.Account.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
		|			OR BudgetDirectCost.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR BudgetDirectCost.CorrAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	BudgetOperations.Ref
		|FROM
		|	Document.Budget.Operations AS BudgetOperations
		|WHERE
		|	(BudgetOperations.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR BudgetOperations.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
		|			OR BudgetOperations.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR BudgetOperations.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	ChangingParametersFAFixedAssets.Ref
		|FROM
		|	Document.FixedAssetDepreciationChanges.FixedAssets AS ChangingParametersFAFixedAssets
		|WHERE
		|	(ChangingParametersFAFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR ChangingParametersFAFixedAssets.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	PayrollEarningRetention.Ref
		|FROM
		|	Document.Payroll.EarningsDeductions AS PayrollEarningRetention
		|WHERE
		|	(PayrollEarningRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR PayrollEarningRetention.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TaxAccrualTaxes.Ref
		|FROM
		|	Document.TaxAccrual.Taxes AS TaxAccrualTaxes
		|WHERE
		|	(TaxAccrualTaxes.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR TaxAccrualTaxes.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TransactionAccountingRecords.Ref
		|FROM
		|	Document.Operation.AccountingRecords AS TransactionAccountingRecords
		|WHERE
		|	(TransactionAccountingRecords.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR TransactionAccountingRecords.AccountDr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
		|			OR TransactionAccountingRecords.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR TransactionAccountingRecords.AccountCr.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	OtherExpensesCosts.Ref
		|FROM
		|	Document.OtherExpenses.Expenses AS OtherExpensesCosts
		|WHERE
		|	(OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR OtherExpensesCosts.GLExpenseAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	Products.Ref
		|FROM
		|	Catalog.Products AS Products
		|WHERE
		|	(Products.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.IndirectExpenses)
		|			OR Products.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.WorkInProgress)
		|			OR Products.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Production))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	BusinessUnits.Ref
		|FROM
		|	Catalog.BusinessUnits AS BusinessUnits
		|WHERE
		|	(BusinessUnits.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			OR BusinessUnits.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
		|			OR BusinessUnits.RecipientOfWastes.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	ManufacturingOperation.Ref
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation";
		
		ResultsArray = Query.ExecuteBatch();
		
		// 1. Order for production Document.
		If Not ResultsArray[0].IsEmpty() Then
			
			ErrorText = NStr("en = 'There are ""Production order"" documents in the infobase. You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Заказ на производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Zlecenie produkcyjne"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos ""Orden de producción"" en la infobase. Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos ""Orden de producción"" en la infobase. Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Infobase''de ""Üretim emri"" belgeleri var. ""Üretim"" onay kutusu temizlenemez.';it = 'Nel database delle informazioni ci sono i documenti ""Ordine di produzione""! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'In der Infobase gibt es ""Produktionsauftrags"" -Dokumente. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 2. Production Document.
		If Not ResultsArray[1].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Production"" documents in the infobase. You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos de ""Producción"" en la infobase. Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos de ""Producción"" en la infobase. Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Infobase''de ""Üretim"" belgeleri var. ""Üretim"" onay kutusu temizlenemez.';it = 'Nella base di informazioni ci sono documenti ""Produzione""! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'In der Infobase gibt es ""Produktion"" -Dokumente. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 3. The Cost allocation document.
		If Not ResultsArray[2].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'The infobase contains documents ""Cost allocation"". Cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Распределение затрат""! Снятие флага ""Производство"" запрещено!';pl = 'Baza informacyjna zawiera dokumenty ""Alokacja kosztów"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'La infobase contiene los documentos ""Asignación de costes"". No se puede vaciar la casilla de verificación ""Producción"".';es_CO = 'La infobase contiene los documentos ""Asignación de costes"". No se puede vaciar la casilla de verificación ""Producción"".';tr = 'Infobase''de ""Maliyet dağıtımı"" belgeleri var. ""Üretim"" onay kutusu temizlenemez.';it = 'Nel database delle informazioni ci sono i documenti ""Allocazione dei costi""! La rimozione del contrassegno ""Produzione"" è vietato!';de = 'Die Infobase enthält Dokumente ""Kostenzuordnung"". Das Kontrollkästchen ""Produktion"" kann nicht gelöscht werden.'");
			
		EndIf;
		
		// 4. Sales order (Order for processing) document.
		If Not ResultsArray[3].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Sales order"" documents with operation ""Processing order"" in the infobase. Cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Заказ покупателя"" с видом операции ""Заказ на переработку"". Снятие флага ""Производство"" запрещено.';pl = 'W bazie informacyjnej istnieją dokumenty ""Zamówienie sprzedaży"", które posiadają rodzaj operacyjny ""Zamówienie na przeróbkę"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos ""Orden de ventas"" con el tipo de operación ""Orden de procesamiento"" en la infobase. No se puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos ""Orden de ventas"" con el tipo de operación ""Orden de procesamiento"" en la infobase. No se puede vaciar la casilla de verificación ""Producción"".';tr = 'Infobase''de ""Sipariş işleniyor"" durumunda olan ""Satış siparişi"" belgeleri var. ""Üretim"" onay kutusu temizlenemez.';it = 'Ci sono documenti ""Ordine cliente"" con operazione ""Ordine di elaborazione"" nell''infobase. Impossibile deselezionare la casella di controllo ""Produzione"".';de = 'In der Infobase befinden sich ""Kundenauftrag"" Belege mit der Operation ""Bearbeitungsreihenfolge"". Das Kontrollkästchen ""Produktion"" kann nicht gelöscht werden.'");
			
		EndIf;
		
		// 5. The Job sheet document
		If Not ResultsArray[4].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Job sheet"" kind in the infobase. Cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Сдельный наряд"". Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Karty zadań"". Nie można wyczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos en el tipo ""Hoja de tareas"" en la infobase. No se puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos en el tipo ""Hoja de tareas"" en la infobase. No se puede vaciar la casilla de verificación ""Producción"".';tr = 'Infobase''de ""İş çizelgesi"" türünde belgeler mevcut. ""Üretim"" onay kutusu temizlenemez.';it = 'Nel database di informazioni ci sono documenti ""Foglio di lavoro""! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'In der Infobase gibt es Dokumente vom Typ ""Arbeitsblatt"". Das Kontrollkästchen ""Produktion"" kann nicht gelöscht werden.'");
			
		EndIf;
		
		// 6. Transfer between cells document (transfer - department).
		If Not ResultsArray[5].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Intra-warehouse transfer"" kind in the infobase where business unit of the company is of ""Department"" type. You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Перемещение по ячейкам"", где структурная единица организации имеет тип ""Подразделение"". Снятие флага ""Производство"" запрещено!';pl = 'Istnieją dokumenty typu ""przesunięcie wewnątrzmagazynowe"" w bazie informacyjnej, gdzie jednostka biznesowa firmy jest typu ""Dział"". Nie można wyczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos en el tipo ""Traslado dentro del almacén"" en la base de información donde la unidad empresarial de la empresa es del tipo ""Departamento"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos en el tipo ""Traslado entre almacenes"" en la infobase donde la unidad de negocio de la empresa es del tipo ""Departamento"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'İş yerinin departmanının “Bölüm” tipinde olduğu veritabanında “Ambar içi transfer” türüne ait belgeler bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nella base informativa ci sono i documenti ""Trasferimenti interni al magazzino"", in cui la Business Unit dell''azienda è di tipo ""Reparto"". La rimozione del contrassegno ""Produzione"" è vietata!';de = 'Es gibt Dokumente der Art ""Lager interner Transfer"" in der Infobase, in der die Geschäftsabteilung der Firma vom Typ ""Abteilung"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 7. The Inventory transfer document (department, indirect costs).
		If Not ResultsArray[6].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Inventory transfer"" kind in the infobase where business unit of the company is of ""Department"" type and/or the account of expenses is of type ""Indirect costs"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Перемещение запасов"", где структурная единица компании имеет тип ""Подразделение"" и/или счет затрат имеет тип ""Косвенные затраты"". Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty typu ""Przesunięcie międzymagazynowe"", gdzie jednostka biznesowa firmy ma typ ""Dział"" i/lub konto rozchodów ma typ ""Koszty pośrednie"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos del tipo ""Traslado del inventario"" en la base de información donde la unidad empresarial de la empresa es del tipo ""Departamento"", y/o la cuenta de gastos es del tipo ""Costes indirectos"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos del tipo ""Traslado de inventario"" en la infobase donde la unidad de negocio de la empresa es del tipo ""Departamento"", y/o la cuenta de gastos es del tipo ""Costes indirectos"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Infobase''de, iş yerinin departmanının “Bölüm” türünde olduğu ve/veya gider hesabının “Dolaylı maliyetler” türünde olduğu “Stok transferi” belgeleri bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nel database delle informazioni ci sono i documenti ""Trasferimento di scorte"", in cui la Business Unit della azienda è di tipo Reparto e / o il conto di spesa è di tipo Costi indiretti! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'In der Infobase gibt es Dokumente der Art ""Bestandsumlagerung"", bei denen der Geschäftsbereich der Firma vom Typ ""Abteilung"" und/oder das Ausgabenkonto vom Typ ""Indirekte Kosten"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 8. Enter opening balance document (department, indirect costs).
		If Not ResultsArray[7].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Enter opening balance"" kind in the infobase where business unit of the company is of ""Department"" type and/or the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Ввод начальных остатков"", где структурная единица компании имеет тип Подразделение и/или счет затрат имеет тип Косвенные затраты или Незавершенное производство! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty typu ""Wprowadzenie salda otwarcia"", gdzie jednostka biznesowa spółki/firmy jest typu ""Dział"" i/lub rachunek wydatków jest typu ""Koszty pośrednie"" albo typu ""Niezakończona produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos del tipo ""Introducir el saldo inicial"" en la base de información donde la unidad empresarial de la empresa es del tipo ""Departamento"", y/o la cuenta de gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos del tipo ""Introducir el saldo de apertura"" en la infobase donde la unidad de negocio de la empresa es del tipo ""Departamento"", y/o la cuenta de gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'İş yerinin departmanının ""Bölüm"" türünde olduğu ve / veya gider hesabının ""Dolaylı maliyetler"" veya ""Bitmemiş üretim"" türünde olduğu veritabanında ""açılış bakiyesi"" türü belgeler bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nel database ci sono i documenti ""Inserimento dei saldi iniziali"", in cui la Business Unit della azienda ha il tipo ""Reparto"" e / o il conto spese è di tipo Costi indiretti o ""Produzione non terminata""! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'Es gibt Dokumente der Art ""Anfangssaldo erfassen"" in der Infobase, wenn die Geschäftsabteilung der Firma vom Typ ""Abteilung"" ist und / oder das Ausgabenkonto vom Typ ""Indirekte Kosten"" oder ""Unfertige Produktion"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 9. Fixed assets enter document (unfinished production, indirect costs).
		If Not ResultsArray[8].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Fixed asset recognition"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Принятие к учету основных средств"", где счет затрат имеет тип ""Косвенные затраты"" или ""Незавершенное производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Przyjęcie do ewidencji środków trwałych"", w których konto rozchodów wydatków posiada rodzaj ""Koszty pośrednie"" lub ""Niezakończona produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos ""Reconocimiento de activos fijos"" en la infobase donde la cuenta de gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos ""Reconocimiento de activos fijos"" en la infobase donde la cuenta de gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Harcama hesabı tipinin ""Dolaylı maliyetler"" ya da ""Bitmemiş üretim"" olduğu veritabanındaki ""Sabit kıymet tanıması"" belgeleri vardır. ""Üretim"" onay kutusunu temizleyemezsiniz.';it = 'Nella base informativa ci sono i documenti ""Riconoscimento cespite"", dove il conto spese è di tipo Costi indiretti o ""Produzione non terminata""! La rimozione della bandiera ""Produzione"" è vietata!';de = 'In der Infobase gibt es Dokumente zur Erfassung des Anlagevermögens, bei denen die Kostenrechnung vom Typ ""Indirekte Kosten"" oder ""Unfertige Erzeugnisse"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 10. Document Inventory receipt (department).
		If Not ResultsArray[9].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are documents of the ""Inventory increase"" kind in the infobase where business unit of the company is of ""Department"" type. You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Оприходование запасов"", где структурная единица компании имеет тип ""Подразделение"". Снятие флага ""Производство"" запрещено!';pl = 'Istnieją dokumenty typu ""Zwiększenie zapasów"" w bazie informacyjnej, gdzie jednostka biznesowa firmy jest typu ""Dział"". Nie można wyczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos del tipo ""Aumento de inventario"" en la base de información donde la unidad empresarial de la empresa es del tipo ""Departamento"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos del tipo ""Aumento de inventario"" en la infobase donde la unidad de negocio de la empresa es del tipo ""Departamento"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'İş yerinin departmanının “Bölüm” tipinde olduğu veritabanında “Stok artırma” türüne ait belgeler bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nella base informativa ci sono i documenti ""Aumento delle scorte"", in cui la Business Unit dell''azienda è di tipo ""Reparto""! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'In der Infobase gibt es Dokumente der Art ""Bestandserhöhung"", in denen die Geschäftsabteilung der Firma vom Typ ""Abteilung"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 11. The Budget document (unfinished production, indirect costs).
		If Not ResultsArray[10].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Budget"" documents in the infobase where the accounts of expenses are of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Бюджет"", где счета затрат имеют тип ""Косвенные затраты"" или ""Незавершенное производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Budżet"", w których rachunki wydatków posiadają rodzaj ""Koszty pośrednie"" lub ""Niezakończona produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos ""Presupuesto"" en la infobase donde las cuentas de gastos son del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos ""Presupuesto"" en la infobase donde las cuentas de gastos son del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Gider hesabının ""Dolaylı maliyetler"" veya ""Bitmemiş üretim"" türünde olduğu ""Bütçe"" veritabanında kayıtlar bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nella base di informazioni ci sono i documenti ""Budget"", dove i conti di spesa sono del tipo Costi indiretti o ""Produzione non terminata""! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'In der Infobase gibt es ""Budget""-Dokumente, bei denen das Ausgabenkonto vom Typ ""Indirekte Kosten"" oder ""Unfertige Erzeugnisse"" sind. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 12. The Fixed asserts modernization document (unfinished production, indirect costs).
		If Not ResultsArray[11].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Fixed asset parameter change"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Изменение параметров основных средств"", где счет затрат имеет тип ""Косвенные затраты"" или ""Незавершенное производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Zmiana parametrów środków trwałych"", w których rachunki wydatków posiadają rodzaj ""Koszty pośrednie"" lub ""Niezakończona produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos ""Cambios del parámetro de activos fijos"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos ""Cambios del parámetro de activos fijos"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Harcama hesabı tipinin ""Dolaylı maliyetler"" ya da ""Bitmemiş üretim"" olduğu veritabanındaki ""Sabit kıymet parametresi değişimi"" belgeleri vardır. ""Üretim"" onay kutusunu temizleyemezsiniz.';it = 'Nella base informativa ci sono i documenti ""Cambiamento dei parametri del cespite"", dove il conto spese è di tipo Costi indiretti o ""Produzione non terminata""! La rimozione della bandiera ""Produzione"" è vietata!';de = 'In der Infobase gibt es Dokumente ""Parameteränderung des Anlagevermögens"", bei denen das Ausgabenkonto vom Typ ""Indirekte Kosten"" oder ""Unfertige Erzeugnisse"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 13. Payroll document (unfinished production, indirect costs).
		If Not ResultsArray[12].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Salary accounting"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Начисление зарплаты"", где счет затрат имеет тип ""Косвенные затраты"" или ""Незавершенное производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Obliczenie wynagrodzeń"", w których rachunek wydatków posiada rodzaj ""Koszty pośrednie"" lub ""Niezakończona produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos ""Contabilidad de salarios"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos ""Contabilidad de salarios"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Gider hesabının ""Dolaylı maliyetler"" veya ""Bitmemiş üretim"" türünde olduğu ""Maaş tahakkuku"" veritabanında kayıtlar bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nella base informativa ci sono i documenti ""Contabilità Stipendi"", in cui il conto spese è di tipo Costi indiretti o ""Produzione non terminata""! La rimozione della bandiera ""Produzione"" è vietata!';de = 'In der Infobase gibt es ""Gehaltsabrechnung"" Belege, bei denen das Ausgabenkonto vom Typ ""Indirekte Kosten"" oder ""Unfertige Produktion"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 14. Tax Earning document (unfinished production, indirect costs).
		If Not ResultsArray[13].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Tax Earning"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Начисление налогов"", где счет затрат имеет тип ""Косвенные затраты"" или ""Незавершенное производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Dochód podatkowy"", w których rachunek wydatków posiada rodzaj ""Koszty pośrednie"" lub ""Niezakończona produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos ""Ingresos de Impuestos"" en la infobase donde la cuenta de los gatos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos ""Ingresos de Impuestos"" en la infobase donde la cuenta de los gatos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Gider hesabının ""Dolaylı maliyetler"" veya ""Bitmemiş üretim"" türünde olduğu ""Vergi tahakkuku"" veritabanında kayıtlar bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nel database delle informazioni ci sono i documenti ""Calcolo delle imposte"", dove il conto spese è di tipo Costi indiretti o ""Produzione non terminata""! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'In der Infobase gibt es Dokumente ""Steuerbezüge"", bei denen das Ausgabenkonto vom Typ ""Indirekte Kosten"" oder ""Unfertige Erzeugnisse"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 15. The Operation document (unfinished production, indirect costs).
		If Not ResultsArray[14].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Operation"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Операция"", где счет затрат имеет тип ""Косвенные затраты"" или ""Незавершенное производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Polecenie księgowania"", w których rachunek wydatków posiada rodzaj ""Koszty pośrednie"" lub ""Niezakończona produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos ""Operación"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos ""Operación"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Gider hesabının ""Dolaylı maliyetler"" veya ""Bitmemiş üretim"" türünde olduğu ""İşlem"" veritabanında kayıtlar bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nel database delle informazioni ci sono i documenti ""Operazione"", dove il conto spese ha il tipo Costi indiretti o ""Produzione non terminata"". La rimozione della bandiera ""Produzione"" è vietata!';de = 'In der Infobase gibt es Dokumente des Typs ""Operation"", bei denen das Ausgabenkonto vom Typ ""Indirekte Kosten"" oder ""Unfertige Erzeugnisse"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 16. The Other expenses document (unfinished production,indirect costs).
		If Not ResultsArray[15].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Other expenses"" documents in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют документы ""Прочие затраты (расходы)"", где счет затрат имеет тип ""Косвенные затраты"" или ""Незавершенное производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją dokumenty ""Inne wydatki"", w których rachunek wydatków posiada rodzaj ""Koszty pośrednie"" lub ""Niezakończona produkcja"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos ""Otros gastos"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos ""Otros gastos"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Gider hesabının ""Dolaylı maliyetler"" veya ""Bitmemiş üretim"" türünde olduğu ""Diğer maliyetler (giderler)"" veritabanında kayıtlar bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nella base informativa ci sono i documenti ""Altre spese"", in cui il conto di costo ha il tipo Costi indiretti o ""Produzione non terminata""! La rimozione del contrassegno ""Produzione"" è vietata!';de = 'In der Infobase gibt es Dokumente ""Sonstige Ausgaben"", bei denen das Ausgabenkonto vom Typ ""Indirekte Kosten"" oder ""Unfertige Erzeugnisse"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 17. Catalog Products (unfinished production, indirect costs).
		If Not ResultsArray[16].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Products"" catalog items in the infobase where the account of expenses is of type ""Indirect costs"" or ""Unfinished production"" and stock replenishment method is of type ""Production"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют элементы справочника ""Номенклатура"", где счет учета затрат имеет тип ""Косвенные затраты"", ""Незавершенное производство"" или способ пополнения запасов ""Производство""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją elementy katalogu ""Produkty"", w których rachunek rozchodów posiada rodzaj ""Koszty pośrednie"" lub ""Niezakończona produkcja"", a metoda uzupełniania zapasów posiada rodzaj ""Produkcja"". Nie można wyczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay artículos del catálogo ""Productos"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"", y el método de reposición del stock es del tipo ""Producción"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay artículos del catálogo ""Productos"" en la infobase donde la cuenta de los gastos es del tipo ""Costes indirectos"" o ""Producción no acabada"", y el método de reposición del stock es del tipo ""Producción"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Gider tablosunun ""Dolaylı maliyetler"" veya ""Bitmemiş üretim"" türünde olduğu ve stok yenileme yönteminin ""Üretim"" türünde olduğu ""Ürünler"" katalog öğeleri bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Ci sono elementi dell''anagrafica ""Articoli"" nel database dove il conto delle spese è di tipo ""Costi indiretti"" o ""Produzione non terminata"" ed il metodo di rifornimento è del tipo ""Produzione"". Non potete cancellare la casella di controllo ""Produzione"".';de = 'In der Infobase gibt es Katalog- Artikel ""Produkte"", bei denen das Ausgabenkonto vom Typ ""Indirekte Kosten"" oder ""Unfertige Produktion"" ist und die Bestandsauffüllungsmethode ist vom Typ ""Produktion"". Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 18. Catalog Structural units (department).
		If Not ResultsArray[17].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'There are ""Business units"" catalog items in the infobase where the auto movement parameter (movement, picking) is of type ""Department"". You cannot clear the ""Production"" check box.'; ru = 'В информационной базе присутствуют элементы справочника ""Структурная единица"", где параметр автоперемещения (перемещение, комплектация) имеет тип ""Подразделение""! Снятие флага ""Производство"" запрещено!';pl = 'W bazie informacyjnej istnieją elementy katalogu ""Jednostki strukturalne"", w których parametr automatycznego przemieszczenia (przemieszczenie, kompletowanie) posiada rodzaj ""Dział"". Nie można oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay artículos del catálogo ""Unidades empresariales"" en la base de información donde el parámetro de auto movimiento (movimiento, elección) es del tipo ""Departamento"". Usted no puede vaciar la casilla de verificación ""Producción"".';es_CO = 'Hay artículos del catálogo ""Unidades de negocio"" en la infobase donde el parámetro de auto movimiento (movimiento, elección) es del tipo ""Departamento"". Usted no puede vaciar la casilla de verificación ""Producción"".';tr = 'Otomatik hareket parametresinin (hareket, toplama) ""Bölüm"" türünde olduğu veritabanında ""Departmanlar"" katalog öğeleri bulunmaktadır. ""Üretim"" onay kutusu temizlenemez.';it = 'Nella base informativa ci sono elementi della directory ""Unità strutturale"", in cui il parametro di auto-spostamento (spostamento, raggruppamento) è di tipo Divisione! La rimozione della bandiera ""Produzione"" è vietata!';de = 'In der Infobase gibt es Katalogelemente ""Geschäftseinheiten"", wobei der automatische Bewegungsparameter (Bewegung, Kommissionierung) vom Typ ""Abteilung"" ist. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		// 19. WIP (ManufacturingOperation) document
		If Not ResultsArray[18].IsEmpty() Then
			
			ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF)
				+ NStr("en = 'There are ""Work-in-progress"" documents in the infobase. You cannot clear the ""Production"" check box.'; ru = 'В информационной базе имеются документы ""Незавершенное производство"". Снятие флага ""Производство"" невозможно.';pl = 'Istnieją dokumenty ""Praca w toku"" w bazie informacyjnej. Nie możesz oczyścić pola wyboru ""Produkcja"".';es_ES = 'Hay documentos de ""Trabajo en progreso"" en la base de información. Usted no puede desmarcar la casilla de verificación ""Producción"".';es_CO = 'Hay documentos de ""Trabajo en progreso"" en la base de información. Usted no puede desmarcar la casilla de verificación ""Producción"".';tr = 'Infobase''de ""İşlem bitişi"" belgeleri var. ""Üretim"" onay kutusu temizlenemez.';it = 'Ci sono documenti di ""Lavori in corso"" nell''infobase. Impossibile deselezionare la casella di controllo ""Produzione"".';de = 'In der Infobase befinden sich ""Arbeit in Bearbeitung""-Dokumente. Sie können das Kontrollkästchen ""Produktion"" nicht deaktivieren.'");
			
		EndIf;
		
		If IsBlankString(ErrorText) Then
			
			ErrorText = CheckRecordsByProductionSubsystemRegisters();
			
		EndIf;
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Uncheck test of the UseProductionOrderStatuses option.
//
&AtServer
Function CancellationUncheckUseProductionOrderStates()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ProductionOrder.Ref,
	|	ProductionOrder.OrderState.OrderStatus AS OrderStatus
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	(ProductionOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR ProductionOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT ProductionOrder.Closed))";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear this check box. Statuses ""Open"" or ""Completed"" (not closed)
			|are already set for Production orders. To be able to clear the check box,
			|change the statuses of these orders. For orders with status ""Open"",
			|change status to ""In progress"" or ""Completed"" (closed).
			|For orders with status ""Completed"" (not closed), change status to ""Completed"" (closed).
			|To do this, close the orders.'; 
			|ru = 'Не удается снять этот флажок. Статусы ""Открыт"" или ""Завершен"" (не закрыт)
			|уже установлены для заказов на производство. Чтобы снять флажок,
			|измените статусы этих заказов. Для заказов со статусом ""Открыт""
			|измените статус на ""В работе"" или ""Завершен"" (закрыт).
			|Для заказов со статусом ""Завершен"" (не закрыт) измените статус на ""Завершен"" (закрыт).
			|Для этого закройте заказы.';
			|pl = 'Nie można oczyścić tego pola wyboru. Statusy ""Otwarte"" lub ""Zakończono"" (nie zamknięte)
			|są już ustawione dla zleceń produkcyjnych. Aby móc oczyścić pole wyboru,
			|zmień statusy tych zamówień. Dla zamówień o statusie ""Otwarte"",
			|zmień status na ""W toku"" lub ""Zakończono"" (zamknięte).
			|Dla zamówień o statusie ""Zakończono"" (nie zamknięte), zmień status na ""Zakończono"" (zamknięte).
			|Aby zrobić to, zamknij zamówienia.';
			|es_ES = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes de producción. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|es_CO = 'No se puede desmarcar esta casilla de verificación. Los estados ""Abrir"" o ""Finalizado"" (no cerrado)
			|ya están establecidos para las órdenes de producción. Para poder desmarcar la casilla de verificación,
			|cambie los estados de estas órdenes. Para las órdenes con estado ""Abrir"",
			|cambie el estado a ""En progreso"" o ""Finalizado"" (cerrado).
			|Para las órdenes con estado ""Finalizado"" (no cerrado), cambie el estado a ""Finalizado"" (cerrado).
			|Para ello, cierre las órdenes.';
			|tr = 'Bu onay kutusu temizlenemiyor.
			|Üretim emirleri için ""Açık"" veya ""Tamamlandı"" (kapatılmadı) durumları belirtildi.
			|Onay kutusunu temizleyebilmek için bu emirlerin durumlarını değiştirin.
			|""Açık"" durumundaki emirlerin durumlarını ""İşlemde"" veya ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|""Tamamlandı"" (kapatılmadı) durumundaki emirlerin durumunu ""Tamamlandı"" (kapatıldı) olarak değiştirin.
			|Bunu yapmak için emirleri kapatın.';
			|it = 'Impossibile deselezionare questa casella di controllo. Gli stati ""Aperto"" o ""Completato"" (non chiuso)
			|sono già impostati per gli Ordini di produzione. Per poter deselezionare la casella di controllo,
			|modificare lo stato di tali ordini. Per gli ordini con stato ""Aperto"", 
			|modificare lo stato a ""In corso"" o ""Completato"" (chiuso).
			| per gli ordini con stato ""Completato"" (non chiuso), modificare lo stato a ""Completato"" (chiuso).
			| Per fare ciò, è necessario chiudere gli ordini.';
			|de = 'Dieses Kontrollkästchen kann nicht deaktiviert werden. Status ""Offen"" oder ""Abgeschlossen"" (nicht geschlossen)
			|sind bereits für Produktionsaufträge festgelegt. Um das Kontrollkästchen
			|deaktivieren zu können, ändern Sie die Status dieser Aufträge. Bei Aufträgen mit dem Status ""Offen"",
			|ändern Sie den Status zu ""In Bearbeitung"" oder ""Abgeschlossen"" (geschlossen).
			|Bei Aufträgen mit dem Status ""Abgeschlossen"" (nicht geschlossen) ändern Sie den Status zu ""Abgeschlossen"" (geschlossen).
			|Um dies zu tun, schließen Sie die Aufträge.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Uncheck test of the UseTechoperations option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseTechOperations()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	Workload.Operation
		|FROM
		|	AccumulationRegister.Workload AS Workload"
	);
	
	QueryResult = Query.Execute();
		
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are documents of the ""Job sheet"" kind or information on work center load in the infobase. You cannot clear the check box.'; ru = 'В базе присутствует информация о загрузке рабочих центров или документы вида ""Сдельный наряд"". Снятие флага запрещено.';pl = 'W bazie informacyjnej istnieją dokumenty typu ""Arkusz pracy"" lub informacje o obciążeniu gniazda produkcyjnego. Nie można oczyścić pola wyboru.';es_ES = 'Hay documentos del tipo ""Hoja de tareas"" o la información sobre la carga del centro de trabajo en la infobase. Usted no puede vaciar la casilla de verificación.';es_CO = 'Hay documentos del tipo ""Hoja de tareas"" o la información sobre la carga del centro de trabajo en la infobase. Usted no puede vaciar la casilla de verificación.';tr = '""İş çizelgesi"" türünün belgeleri veya veritabanındaki iş merkezi yükü hakkında bilgi vardır. Onay kutusu temizlenemez.';it = 'Ci sono documenti della ""Foglio di Lavoro"" tipo o informazioni su centro di lavoro carico di infobase. Non è possibile deselezionare la casella di controllo.';de = 'In der Infobase gibt es Dokumente vom Typ ""Arbeitsblatt"" oder Informationen zur Auslastung des Arbeitsplatzes. Sie können das Kontrollkästchen nicht deaktivieren.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CancellationUncheckConstantUseResourcesWorkloadPlanning()
	
	ErrorText = "";
	
	If Constants.UseProductionPlanning.Get() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. First, clear the ""Use production planning"" checkbox.'; ru = 'Не удалось снять флажок. Сначала снимите флажок ""Планировать производство"".';pl = 'Nie można odznaczyć pola wyboru. Najpierw, wyczyść pole wyboru ""Użycie planowania produkcji"".';es_ES = 'No se puede desmarcar la casilla de verificación. Primero, desmarque la casilla de verificación ""Utilizar la planificación de producción"".';es_CO = 'No se puede desmarcar la casilla de verificación. Primero, desmarque la casilla de verificación ""Utilizar la planificación de producción"".';tr = 'Onay kutusu temizlenemiyor. Önce ""Üretim planlamasını kullan"" onay kutusunu temizleyin.';it = 'Impossibile disabilitare la casella di controllo. Innanzitutto, disabilitare la casella di controllo ""Usa la pianificazione di produzione"".';de = 'Das Kontrollkästchen kann nicht deaktiviert werden. Zuerst deaktivieren Sie das Kontrollkästchen Produktionsplanung verwenden.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Uncheck test of the UseProductionPlanning option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseProductionPlanning()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	ProductionOrder.Ref AS Ref
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Posted
		|	AND ProductionOrder.UseProductionPlanning");
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are documents of the ""Production order"" using production planing in the infobase. You cannot clear the check box.'; ru = 'В информационной базе имеются документы ""Заказа на производство"" с использованием планирования производства. Снятие флага запрещено.';pl = 'Istnieją dokumenty ""Zlecenie produkcyjne"" za pomocą planowania produkcji w bazie informacyjnej. Nie można oczyścić pola wyboru.';es_ES = 'Hay documentos de la ""Orden de producción"" utilizando la planificación de la producción en la infobase. No puede vaciar la casilla de verificación.';es_CO = 'Hay documentos de la ""Orden de producción"" utilizando la planificación de la producción en la infobase. No puede vaciar la casilla de verificación.';tr = 'Infobase''de üretim planlamasını kullanan ""Üretim emri"" belgeleri var. Onay kutusu temizlenemez.';it = 'Ci sono documenti dell'' ""Ordine di produzione"" che utilizzano la pianificazione di produzione nell''infobase. Impossibile deselezionare la casella di controllo.';de = 'In der Infobase befinden sich die ""Produktionsauftrag""-Dokumente die Produktionsplanung verwenden. Sie können dieses Kontrollkästchen nicht deaktivieren.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Uncheck test of the UseProductionPlanning option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseProductionTask()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	ProductionTask.Ref AS Ref
		|FROM
		|	Document.ProductionTask AS ProductionTask
		|WHERE
		|	ProductionTask.Posted");
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear this check box. Production tasks are already created.'; ru = 'Не удается снять флажок. Производственные задачи уже созданы.';pl = 'Nie można wyczyścić pola wyboru. Zadania produkcyjne są już utworzone.';es_ES = 'No puedo desmarcar esta casilla de verificación. Las tareas de producción ya están creadas.';es_CO = 'No puedo desmarcar esta casilla de verificación. Las tareas de producción ya están creadas.';tr = 'Bu onay kutusu temizlenemez. Üretim görevleri zaten oluşturuldu.';it = 'Impossibile deselezionare questa casella di controllo. Gli incarichi di produzione sono già stati creati.';de = 'Dieses Kontrollkästchen kann nicht gelöscht werden. Produktionsaufgaben sind bereits erstellt.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	If AttributePathToData = "ConstantsSet.UseProductionSubsystem" Then
		
		If Constants.UseProductionSubsystem.Get() <> ConstantsSet.UseProductionSubsystem Then
		
			ErrorText = CancellationUncheckFunctionalOptionUseSubsystemProduction();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 			AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	Not ConstantsSet.UseProductionSubsystem);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are the Production Order documents with the status different from Executed, the flag removal is prohibited.
	If AttributePathToData = "ConstantsSet.UseProductionOrderStatuses" Then
		
		If Constants.UseProductionOrderStatuses.Get() <> ConstantsSet.UseProductionOrderStatuses
			AND (NOT ConstantsSet.UseProductionOrderStatuses) Then
			
			ErrorText = CancellationUncheckUseProductionOrderStates();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If InProcessStatus for the Production order documents are used,the field is required to be filled in.
	If AttributePathToData = "ConstantsSet.ProductionOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseProductionOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.ProductionOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several production order states"" check box is cleared but the ""In progress"" production order state parameter is not filled in.'; ru = 'Снят флаг ""Использовать несколько состояний заказов на производство"", но не заполнен параметр состояния заказа на производство ""В работе""!';pl = 'Z pola wyboru ""Użyj kilku stanów zleceń produkcyjnych"" usunięto zaznaczenie, ale parametr statusu zamówienia produkcyjnego ""W toku"" nie został wypełniony.';es_ES = 'La casilla de verificación ""Utilizar varios estados de órdenes producción"" está vaciada pero el parámetro del estado del orden de producción ""En progreso"" no está rellenado.';es_CO = 'La casilla de verificación ""Utilizar varios estados de órdenes producción"" está vaciada pero el parámetro del estado del orden de producción ""En progreso"" no está rellenado.';tr = '""Birkaç üretim emri durumu kullan"" onay kutusu temizlendi, ancak ""Devam ediyor"" üretim emri durumu parametresi doldurulmadı.';it = 'La casella di controllo ""Itilizzare diversi stati ordini di produzione"" è stata deselezionata, ma il parametro di stato ordine di produzione ""In corso"" non è compilato.';de = 'Das Kontrollkästchen ""Mehrere Status von Produktionsauftrag verwenden"" ist deaktiviert, aber der Statusparameter von Produktionsauftrag ""In Bearbeitung"" ist nicht aufgefüllt.'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.ProductionOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// If StatusExecuted for the ProductionOrders documents are used,the field is required to be filled in.
	If AttributePathToData = "ConstantsSet.ProductionOrdersCompletionStatus" Then
		
		If Not ConstantsSet.UseProductionOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.ProductionOrdersCompletionStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several production order states"" check box is cleared, but the ""Completed"" production order state parameter is not filled in.'; ru = 'Снят флаг ""Использовать несколько состояний заказов на производство"", но не заполнен параметр состояния заказа на производство ""Завершен""!';pl = 'Pole wyboru ""Użycie kilku stanów zleceń produkcyjnych"" zostało odznaczone, ale parametr statusu zlecenia produkcyjnego ""Zakończono"" nie został wypełniony.';es_ES = 'La casilla de verificación ""Utilizar varios estados de órdenes de producción"", pero el parámetro del estado del orden de producción ""Finalizado"" no está rellenado.';es_CO = 'La casilla de verificación ""Utilizar varios estados de órdenes de producción"", pero el parámetro del estado del orden de producción ""Finalizado"" no está rellenado.';tr = '""Birkaç üretim emri durumu kullan"" onay kutusu temizlendi, ancak ""Tamamlandı"" üretim emri durumu parametresi doldurulmadı.';it = 'La casella di controllo ""utilizzare gli stati diversi ordini di produzione"" viene cancellato, ma il ""Completato"" parametro di stato ordine di produzione non è compilato in.';de = 'Das Kontrollkästchen ""Mehrere Produktionsauftragszustände verwenden"" ist deaktiviert, aber der Produktionsparameter ""Abgeschlossen"" ist nicht ausgefüllt.'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.ProductionOrdersCompletionStatus.Get());
			
		EndIf; 
		
	EndIf;
	
	// If there are any activities on the registers "Work centers loading", on the register "Job sheet" or the products
	// with the Operation type, the removal of the UseOperationsManagement flag is prohibited
	If AttributePathToData = "ConstantsSet.UseOperationsManagement" Then
		
		If Constants.UseOperationsManagement.Get() <> ConstantsSet.UseOperationsManagement 
			AND (NOT ConstantsSet.UseOperationsManagement) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseTechOperations();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
		
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseResourcesWorkloadPlanning" Then
		
		If Constants.UseResourcesWorkloadPlanning.Get() <> ConstantsSet.UseResourcesWorkloadPlanning
			And (Not ConstantsSet.UseResourcesWorkloadPlanning) Then
			
			ErrorText = CancellationUncheckConstantUseResourcesWorkloadPlanning();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseProductionPlanning" Then
		
		If Constants.UseProductionPlanning.Get() <> ConstantsSet.UseProductionPlanning 
			And (Not ConstantsSet.UseProductionPlanning) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseProductionPlanning();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseProductionTask" Then
		
		If Constants.UseProductionTask.Get() <> ConstantsSet.UseProductionTask 
			And (Not ConstantsSet.UseProductionTask) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseProductionTask();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.MaxNumberOfBOMLevels" Then
		
		MaxNumberOfBOMLevels = Constants.MaxNumberOfBOMLevels.Get();
		
		If MaxNumberOfBOMLevels <> ConstantsSet.MaxNumberOfBOMLevels
			And MaxNumberOfBOMLevels > ConstantsSet.MaxNumberOfBOMLevels Then
			
			ErrorText = CancellationDecreaseMaxBOMLevel(MaxNumberOfBOMLevels);
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",			AttributePathToData);
				Result.Insert("ErrorText",		ErrorText);
				Result.Insert("CurrentValue",	MaxNumberOfBOMLevels);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtServer
Function CancellationDecreaseMaxBOMLevel(MaxValue) Export
	
	ErrorText = "";
	MaxNumberOfBOMLevels = ConstantsSet.MaxNumberOfBOMLevels;
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	BillsOfMaterials.Ref AS Specification
	|INTO BOMLevel_0
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON BillsOfMaterials.Ref = BillsOfMaterialsContent.Specification
	|WHERE
	|	BillsOfMaterialsContent.Ref IS NULL";
	
	QueryTextFragment1 = "";
	QueryTextFragment2 = DriveClientServer.GetQueryDelimeter();
	
	For i = 1 To MaxValue Do
		
		Text1 = DriveClientServer.GetQueryDelimeter() + "
			|SELECT DISTINCT
			|	BillsOfMaterialsContent.Specification AS Specification,
			|	%3 AS Level
			|INTO %1
			|FROM
			|	%2 AS BOMTable
			|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
			|		ON BOMTable.Specification = BillsOfMaterialsContent.Ref
			|		AND (BOMTable.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef))";
		
		QueryTextFragment1 = QueryTextFragment1 + StrTemplate(Text1, "BOMLevel_" + String(i), "BOMLevel_" + String(i-1), String(i));
		
		Text2 = ?(i = 1, "", DriveClientServer.GetQueryUnion()) + "
			|SELECT
			|	BOMTable.Level
			|%2
			|FROM
			|	%1 AS BOMTable";
		
		QueryTextFragment2 = QueryTextFragment2 + StrTemplate(Text2, "BOMLevel_" + String(i), ?(i = 1, "INTO BOMLevelTable", ""));
		
	EndDo;
	
	Query.Text = Query.Text + QueryTextFragment1 + QueryTextFragment2 + DriveClientServer.GetQueryDelimeter() + "
		|SELECT
		|	ISNULL(MAX(BOMLevelTable.Level), 0) AS Level
		|FROM
		|	BOMLevelTable AS BOMLevelTable";
	
	QueryResultTable = Query.Execute().Unload();
	If QueryResultTable.Count() > 0 Then
		
		Level = QueryResultTable[0].Level;
		If Level > MaxNumberOfBOMLevels Then
			ErrorText = NStr("en = 'The max number of BOM levels cannot be less then
									|the number of BOM levels (%1) in catalog ""Bills of materials"".'; 
									|ru = 'Максимальное количество уровней спецификации не может быть меньше
									|количества уровней спецификаций (%1) в справочнике ""Спецификации"".';
									|pl = 'Maksymalna ilość poziomów specyfikacji materiałowej nie może być mniejsza niż
									|ilość poziomów specyfikacji materiałowej (%1) w katalogu ""Specyfikacje materiałowe"".';
									|es_ES = 'El número máximo de niveles de la lista de materiales no puede ser inferior 
									|al número de niveles de la lista de materiales (%1) del catálogo ""Listas de materiales"".';
									|es_CO = 'El número máximo de niveles de la lista de materiales no puede ser inferior 
									|al número de niveles de la lista de materiales (%1) del catálogo ""Listas de materiales"".';
									|tr = 'Maksimum ürün reçetesi seviyesinin sayısı ""Ürün reçeteleri"" kataloğundaki
									|ürün reçetesi seviyelerinin sayısından (%1) az olamaz.';
									|it = 'Il numero massimo di livelli di distinta base non può essere inferiore
									|al numero di livelli di distinta base (%1) nel catalogo ""Distinte base"".';
									|de = 'Die Höchstanzahl von Stücklistenstufen kann nicht geringer als 
									|die Zahl von Stücklistenstufen (%1) in Katalog ""Stücklisten"" sein.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, Level);
		EndIf;
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

#EndRegion

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - handler of the ProductionOrderstatusesCatalog command.
//
&AtClient
Procedure CatalogProductionOrderStates(Command)
	
	OpenForm("Catalog.ProductionOrderStatuses.ListForm");
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonCached.ApplicationRunMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet" Then
		
		If Source = "UseBatches" Then
			
			CommonClientServer.SetFormItemProperty(Items, "Group4", "Enabled", Parameter.Value);
			
		EndIf;
		
		If Source = "CanReceiveSubcontractingServices" Then
			
			CommonClientServer.SetFormItemProperty(Items,
				"UseSubcontractorManufacturers",
				"Enabled",
				Not Parameter.Value);
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - handler of the OnChange event of the UseProductionOrderStatuses field
//
&AtClient
Procedure FunctionalOptionUseSubsystemProductionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseResourcesWorkloadPlanningOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseProductionPlanningOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure PlanningHorizonOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseProductionOrderStatuses field
//
&AtClient
Procedure UseStatusesProductionOrderOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the InProcessStatus field.
//
&AtClient
Procedure InProcessStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the CompletedStatus field.
//
&AtClient
Procedure CompletedStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - the OnChange event handler of the UseOperationsManagement field.
//
&AtClient
Procedure FunctionalOptionUseTechOperationsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure UseProductionTaskOnChange(Item)
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Item", Item);
	
	NotifyDescription = New NotifyDescription("UseProductionTaskOnChangeEnd", ThisObject, AdditionalParameters);
	ShowQueryBox(NotifyDescription,
		NStr("en = 'Applying the settings might take some time. During this time, users may not be able to manage business documents.
			|So, it is recommended to apply the settings when the number of logged in users is minimum.
			|Do you want to continue?'; 
			|ru = 'Применение настроек может занять некоторое время. В течение этого времени пользователи не смогут управлять коммерческими документами.
			|Рекомендуется применить настройки при минимальном количестве активных пользователей.
			|Продолжить?';
			|pl = 'Zastosowanie ustawień może zająć trochę czasu. Podczas tego czasu, użytkownicy nie mogą zarządzać dokumentami biznesowymi.
			|Więc, zalecane jest zastosowanie ustawień podczas, gdy liczba zalogowanych użytkowników jest minimalna.
			|Czy chcesz kontynuować?';
			|es_ES = 'Aplicar las configuraciones podría llevar algún tiempo. Durante este período, es posible que los usuarios no puedan gestionar los documentos comerciales.
			|Por lo tanto, se recomienda aplicar la configuración cuando el número de usuarios conectados sea mínimo.
			|¿Quiere continuar?';
			|es_CO = 'Aplicar las configuraciones podría llevar algún tiempo. Durante este período, es posible que los usuarios no puedan gestionar los documentos comerciales.
			|Por lo tanto, se recomienda aplicar la configuración cuando el número de usuarios conectados sea mínimo.
			|¿Quiere continuar?';
			|tr = 'Ayarların uygulanması biraz zaman alabilir. Bu süreçte kullanıcılar iş evraklarını yönetemeyebilir.
			|O yüzden giriş yapmış kullanıcılar en az sayıdayken ayarların uygulanması tavsiye ediliyor.
			|Devam etmek istiyor musunuz?';
			|it = 'L''applicazione delle impostazione potrebbe richiedere un po'' di tempo. Durante questa fase, potrebbe essere preclusa agli utenti la gestione dei documenti aziendali.
			|Dunque è consigliato di applicare le impostazioni quando il numero di utenti registrati è al minimo.
			|Continuare?';
			|de = 'Das Anwenden der Einstellungen kann einige Zeit in Anspruch nehmen. Während dieser Zeit können Benutzer möglicherweise keine Geschäftsdokumente verwalten.
			|Es wird empfohlen, die Einstellungen zu übernehmen, wenn die Anzahl der angemeldeten Benutzer minimal ist.
			|Möchten Sie fortsetzen?'"),
		QuestionDialogMode.YesNo);
		
EndProcedure

&AtClient
Procedure UseProductionTaskOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	Attachable_OnAttributeChange(AdditionalParameters.Item);
	
EndProcedure

// Procedure - the OnChange event handler of the UseOperationsManagement field.
//
&AtClient
Procedure FunctionalOptionTollingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseSubcontractorManufacturers field.
//
&AtClient
Procedure FunctionalOptionTransferRawMaterialsForProcessingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure MaxNumberOfBOMLevelsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion