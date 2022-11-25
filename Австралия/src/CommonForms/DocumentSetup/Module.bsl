#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Procedure write user settings in register.
//
Procedure SetSetting(SettingName)
	
	User = Users.CurrentUser();
	
	RecordSet = InformationRegisters.UserSettings.CreateRecordSet();
	
	RecordSet.Filter.User.Use = True;
	RecordSet.Filter.User.Value	  = User;
	RecordSet.Filter.Setting.Use	  = True;
	RecordSet.Filter.Setting.Value		  = ChartsOfCharacteristicTypes.UserSettings[SettingName];
	
	Record = RecordSet.Add();
	
	Record.User = User;
	Record.Setting    = ChartsOfCharacteristicTypes.UserSettings[SettingName];
	Record.Value     = ChartsOfCharacteristicTypes.UserSettings[SettingName].ValueType.AdjustValue(ThisForm[SettingName]);
	
	RecordSet.Write();
	
EndProcedure

&AtServer
// Procedure write user settings in register.
//
Procedure WriteNewSettings()
	
	If ValueIsFilled(WorkKindPositionInWorkOrder) Then
		SetSetting("WorkKindPositionInWorkOrder");
	EndIf;
	If ValueIsFilled(WorkKindPositionInWorkTask) Then
		SetSetting("WorkKindPositionInWorkTask");
	EndIf;
	If ValueIsFilled(ShipmentDatePositionInSalesOrder) Then
		SetSetting("ShipmentDatePositionInSalesOrder");
	EndIf;
	If ValueIsFilled(ReceiptDatePositionInPurchaseOrder) Then
		SetSetting("ReceiptDatePositionInPurchaseOrder");
	EndIf;
	If ValueIsFilled(ReceiptDatePositionInRequisitionOrder) Then
		SetSetting("ReceiptDatePositionInRequisitionOrder");
	EndIf;
	If ValueIsFilled(SalesOrderPositionInShipmentDocuments) Then
		SetSetting("SalesOrderPositionInShipmentDocuments");
	EndIf;
	If ValueIsFilled(SalesOrderPositionInInventoryTransfer) Then
		SetSetting("SalesOrderPositionInInventoryTransfer");
	EndIf;
	If ValueIsFilled(PurchaseOrderPositionInReceiptDocuments) Then
		SetSetting("PurchaseOrderPositionInReceiptDocuments");
	EndIf;	 
	If ValueIsFilled(UseConsumerMaterialsInWorkOrder) Then
		SetSetting("UseConsumerMaterialsInWorkOrder");
	EndIf;	 
	If ValueIsFilled(UseProductsInWorkOrder) Then
		SetSetting("UseProductsInWorkOrder");
	EndIf;	 
	If ValueIsFilled(UseMaterialsInWorkOrder) Then
		SetSetting("UseMaterialsInWorkOrder");
	EndIf;
	If ValueIsFilled(UsePerformerSalariesInWorkOrder) Then
		SetSetting("UsePerformerSalariesInWorkOrder");
	EndIf;
	If ValueIsFilled(PositionAssignee) Then
		SetSetting("PositionAssignee");
	EndIf;
	If ValueIsFilled(PositionResponsible) Then
		SetSetting("PositionResponsible");
	EndIf;
	If ValueIsFilled(CounterpartyAndContractPositionInActualSalesVolume) Then
		SetSetting("CounterpartyAndContractPositionInActualSalesVolume");
	EndIf;
	If ValueIsFilled(InventoryStructuralUnitPositionInWIP) Then
		SetSetting("InventoryStructuralUnitPositionInWIP");
	EndIf;
	
	RefreshReusableValues();
	
EndProcedure

&AtClient
// Procedure checks if the form was modified.
//
Procedure CheckIfFormWasModified(StructureOfFormAttributes)

	WereMadeChanges = False;
	
	ChangesOfCounterpartyAndContractPositionInActualSalesVolume =
		(CounterpartyAndContractPositionInActualSalesVolumeOnOpen <> CounterpartyAndContractPositionInActualSalesVolume);
	
	ChangesOfPositionOfWorkKindInWorkOrder				= WorkKindPositionInWorkOrderOnOpen <> WorkKindPositionInWorkOrder;
	ChangesOfWorkKindPositionInWorkTask					= WorkKindPositionInWorkTaskOnOpen <> WorkKindPositionInWorkTask;
	ChangesOfShipmentDatePositionInSalesOrder			= ShipmentDatePositionInSalesOrderOnOpen <> ShipmentDatePositionInSalesOrder;
	ChangesOfReceiptDatePositionInPurchaseOrder			= ReceiptDatePositionInPurchaseOrderOnOpen <> ReceiptDatePositionInPurchaseOrder;
	ChangesOfReceiptDatePositionInRequisitionOrder		= ReceiptDatePositionInRequisitionOrderOnOpen <> ReceiptDatePositionInRequisitionOrder;
	ChangesOfSalesOrderPositionInShipmentDocuments		= SalesOrderPositionInShipmentDocumentsOnOpen <> SalesOrderPositionInShipmentDocuments;
	ChangesOfSalesOrderPositionInInventoryTransfer		= SalesOrderPositionInInventoryTransferOnOpen <> SalesOrderPositionInInventoryTransfer;
	ChangesOfPurchaseOrderPositionInReceiptDocuments	= LocationOfSupplierOrderInIncomeDocumentsOnOpen <> PurchaseOrderPositionInReceiptDocuments;
	ChangesOfUseConsumerMaterialsInWorkOrder			= UseConsumerMaterialsInWorkOrderOnOpen <> UseConsumerMaterialsInWorkOrder;
	ChangesOfUseGoodsInWorkOrder						= UseGoodsInWorkOrderOnOpen <> UseProductsInWorkOrder;
	ChangesOfUseMaterialsInWorkOrder					= UseMaterialsInWorkOrderOnOpen <> UseMaterialsInWorkOrder;
	ChangesOfUsePerformerSalariesInWorkOrder			= UsePerformerSalariesInWorkOrderOnOpen <> UsePerformerSalariesInWorkOrder;
	ChangesOfPositionAssignee							= PositionAssigneeOnOpen <> PositionAssignee;
	ChangesOfPositionResponsible						= PositionResponsibleOnOpen <> PositionResponsible;
	ChangesOfSalesOrderPositionInTransferOrder 			= SalesOrderPositionInTransferOrderOnOpen <> SalesOrderPositionInTransferOrder;
	ChangesOfInventoryStructuralUnitPositionInWIP		= (InventoryStructuralUnitPositionInWIPOnOpen <> InventoryStructuralUnitPositionInWIP);
	
	If ChangesOfPositionOfWorkKindInWorkOrder
	 Or ChangesOfWorkKindPositionInWorkTask
	 Or ChangesOfShipmentDatePositionInSalesOrder
	 Or ChangesOfReceiptDatePositionInPurchaseOrder
	 Or ChangesOfSalesOrderPositionInShipmentDocuments
	 Or ChangesOfSalesOrderPositionInInventoryTransfer
	 Or ChangesOfSalesOrderPositionInTransferOrder
	 Or ChangesOfPurchaseOrderPositionInReceiptDocuments 
	 Or ChangesOfUseConsumerMaterialsInWorkOrder
	 Or ChangesOfUseGoodsInWorkOrder
	 Or ChangesOfUseMaterialsInWorkOrder
	 Or ChangesOfUsePerformerSalariesInWorkOrder
	 Or ChangesOfPositionAssignee
	 Or ChangesOfPositionResponsible 
	 Or ChangesOfReceiptDatePositionInRequisitionOrder
	 Or ChangesOfCounterpartyAndContractPositionInActualSalesVolume
	 Or ChangesOfInventoryStructuralUnitPositionInWIP Then
		
		WereMadeChanges = True;
		
	EndIf;
	
	StructureOfFormAttributes.Insert("WereMadeChanges",									WereMadeChanges);
	StructureOfFormAttributes.Insert("WorkKindPositionInWorkOrder",					 	WorkKindPositionInWorkOrder);
	StructureOfFormAttributes.Insert("WorkKindPositionInWorkTask",				 		WorkKindPositionInWorkTask);
	StructureOfFormAttributes.Insert("ShipmentDatePositionInSalesOrder",			 	ShipmentDatePositionInSalesOrder);
	StructureOfFormAttributes.Insert("ReceiptDatePositionInPurchaseOrder",		 		ReceiptDatePositionInPurchaseOrder);
	StructureOfFormAttributes.Insert("SalesOrderPositionInShipmentDocuments",	 		SalesOrderPositionInShipmentDocuments);
	StructureOfFormAttributes.Insert("SalesOrderPositionInInventoryTransfer",	 		SalesOrderPositionInInventoryTransfer);
	StructureOfFormAttributes.Insert("SalesOrderPositionInTransferOrder",	 			SalesOrderPositionInTransferOrder);
	StructureOfFormAttributes.Insert("PurchaseOrderPositionInReceiptDocuments", 		PurchaseOrderPositionInReceiptDocuments);
	StructureOfFormAttributes.Insert("UseConsumerMaterialsInWorkOrder",		 			UseConsumerMaterialsInWorkOrder);
	StructureOfFormAttributes.Insert("UseProductsInWorkOrder",					 		UseProductsInWorkOrder);
	StructureOfFormAttributes.Insert("UseMaterialsInWorkOrder",				 			UseMaterialsInWorkOrder);
	StructureOfFormAttributes.Insert("UsePerformerSalariesInWorkOrder",	 				UsePerformerSalariesInWorkOrder);
	StructureOfFormAttributes.Insert("PositionResponsible",							 	PositionResponsible);
	StructureOfFormAttributes.Insert("PositionAssignee",							 	PositionAssignee);
	StructureOfFormAttributes.Insert("InventoryStructuralUnitPositionInWIP",			InventoryStructuralUnitPositionInWIP);
	
	StructureOfFormAttributes.Insert("CounterpartyAndContractPositionInActualSalesVolume",
		CounterpartyAndContractPositionInActualSalesVolume);

EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	WereMadeChanges = False;
	RememberSelection = False;
	
	If Parameters.Property("CounterpartyAndContractPositionInActualSalesVolume") Then
		CounterpartyAndContractPositionInActualSalesVolume =
			Parameters.CounterpartyAndContractPositionInActualSalesVolume;
		CounterpartyAndContractPositionInActualSalesVolumeOnOpen =
			Parameters.CounterpartyAndContractPositionInActualSalesVolume;
		Items.GroupCounterpartyAndContractPositionInActualSalesVolume.Visible = True;
		Items.CounterpartyAndContractPositionInActualSalesVolume.Visible = True;
	Else
		Items.GroupCounterpartyAndContractPositionInActualSalesVolume.Visible = False;
		Items.CounterpartyAndContractPositionInActualSalesVolume.Visible = False;
	EndIf;
	
	If Parameters.Property("WorkKindPositionInWorkOrder") Then
		WorkKindPositionInWorkOrder = Parameters.WorkKindPositionInWorkOrder;
		WorkKindPositionInWorkOrderOnOpen = Parameters.WorkKindPositionInWorkOrder;
		Items.GroupWorkKindPositionInWorkOrder.Visible = True;
		Items.WorkKindPositionInWorkOrder.Visible = True;
	Else
		Items.GroupWorkKindPositionInWorkOrder.Visible = False;
		Items.WorkKindPositionInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("WorkKindPositionInWorkTask") Then
		WorkKindPositionInWorkTask = Parameters.WorkKindPositionInWorkTask;
		WorkKindPositionInWorkTaskOnOpen = Parameters.WorkKindPositionInWorkTask;
		Items.GroupPositionOfWorkKindInWorkTask.Visible = True;
		Items.WorkKindPositionInWorkTask.Visible = True;
	Else
		Items.GroupPositionOfWorkKindInWorkTask.Visible = False;
		Items.WorkKindPositionInWorkTask.Visible = False;
	EndIf;
	
	If Parameters.Property("ShipmentDatePositionInSalesOrder") Then
		ShipmentDatePositionInSalesOrder = Parameters.ShipmentDatePositionInSalesOrder;
		ShipmentDatePositionInSalesOrderOnOpen = Parameters.ShipmentDatePositionInSalesOrder;
		Items.GroupShipmentDatePositionInSalesOrder.Visible = True;
		Items.ShipmentDatePositionInSalesOrder.Visible = True;
	Else
		Items.GroupShipmentDatePositionInSalesOrder.Visible = False;
		Items.ShipmentDatePositionInSalesOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("ReceiptDatePositionInPurchaseOrder") Then
		ReceiptDatePositionInPurchaseOrder = Parameters.ReceiptDatePositionInPurchaseOrder;
		ReceiptDatePositionInPurchaseOrderOnOpen = Parameters.ReceiptDatePositionInPurchaseOrder;
		Items.GroupReceiptDatePositionInPurchaseOrder.Visible = True;
		Items.ReceiptDatePositionInPurchaseOrder.Visible = True;
	Else
		Items.GroupReceiptDatePositionInPurchaseOrder.Visible = False;
		Items.ReceiptDatePositionInPurchaseOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("ReceiptDatePositionInRequisitionOrder") Then
		ReceiptDatePositionInRequisitionOrder = Parameters.ReceiptDatePositionInRequisitionOrder;
		ReceiptDatePositionInRequisitionOrderOnOpen = Parameters.ReceiptDatePositionInRequisitionOrder;
		Items.GroupReceiptDatePositionInRequisitionOrder.Visible = True;
		Items.ReceiptDatePositionInRequisitionOrder.Visible = True;
	Else
		Items.GroupReceiptDatePositionInRequisitionOrder.Visible = False;
		Items.ReceiptDatePositionInRequisitionOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("SalesOrderPositionInShipmentDocuments") Then
		SalesOrderPositionInShipmentDocuments = Parameters.SalesOrderPositionInShipmentDocuments;
		SalesOrderPositionInShipmentDocumentsOnOpen = Parameters.SalesOrderPositionInShipmentDocuments;
		Items.GroupSalesOrderPositionInShipmentDocuments.Visible = True;
		Items.SalesOrderPositionInShipmentDocuments.Visible = True;
	Else
		Items.GroupSalesOrderPositionInShipmentDocuments.Visible = False;
		Items.SalesOrderPositionInShipmentDocuments.Visible = False;
	EndIf;
	
	If Parameters.Property("SalesOrderPositionInInventoryTransfer") Then
		SalesOrderPositionInInventoryTransfer = Parameters.SalesOrderPositionInInventoryTransfer;
		SalesOrderPositionInInventoryTransferOnOpen = Parameters.SalesOrderPositionInInventoryTransfer;
		Items.GroupSalesOrderPositionInInventoryTransfer.Visible = True;
		Items.SalesOrderPositionInInventoryTransfer.Visible = True;
	Else
		Items.GroupSalesOrderPositionInInventoryTransfer.Visible = False;
		Items.SalesOrderPositionInInventoryTransfer.Visible = False;
	EndIf;
	
	If Parameters.Property("SalesOrderPositionInTransferOrder") Then
		SalesOrderPositionInTransferOrder = Parameters.SalesOrderPositionInTransferOrder;
		SalesOrderPositionInTransferOrderOnOpen = Parameters.SalesOrderPositionInTransferOrder;
		Items.GroupSalesOrderPositionInTransferOrder.Visible = True;
		Items.SalesOrderPositionInTransferOrder.Visible = True;
	Else
		Items.GroupSalesOrderPositionInTransferOrder.Visible = False;
		Items.SalesOrderPositionInTransferOrder.Visible = False;
	EndIf;

	If Parameters.Property("PurchaseOrderPositionInReceiptDocuments") Then
		PurchaseOrderPositionInReceiptDocuments = Parameters.PurchaseOrderPositionInReceiptDocuments;
		LocationOfSupplierOrderInIncomeDocumentsOnOpen = Parameters.PurchaseOrderPositionInReceiptDocuments;
		Items.GroupPurchaseOrderPositionInReceiptDocuments.Visible = True;
		Items.PurchaseOrderPositionInReceiptDocuments.Visible = True;
	Else
		Items.GroupPurchaseOrderPositionInReceiptDocuments.Visible = False;
		Items.PurchaseOrderPositionInReceiptDocuments.Visible = False;
	EndIf;
	
	If Parameters.Property("UseConsumerMaterialsInWorkOrder") Then
		UseConsumerMaterialsInWorkOrder = Parameters.UseConsumerMaterialsInWorkOrder;
		UseConsumerMaterialsInWorkOrderOnOpen = Parameters.UseConsumerMaterialsInWorkOrder;
		Items.GroupUseConsumerMaterialsInWorkOrder.Visible = True;
		Items.UseConsumerMaterialsInWorkOrder.Visible = True;
	Else
		Items.GroupUseConsumerMaterialsInWorkOrder.Visible = False;
		Items.UseConsumerMaterialsInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("UseProductsInWorkOrder") Then
		UseProductsInWorkOrder = Parameters.UseProductsInWorkOrder;
		UseGoodsInWorkOrderOnOpen = Parameters.UseProductsInWorkOrder;
		Items.GroupUseProductsInWorkOrder.Visible = True;
		Items.UseProductsInWorkOrder.Visible = True;
	Else
		Items.GroupUseProductsInWorkOrder.Visible = False;
		Items.UseProductsInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("UseMaterialsInWorkOrder") Then
		UseMaterialsInWorkOrder = Parameters.UseMaterialsInWorkOrder;
		UseMaterialsInWorkOrderOnOpen = Parameters.UseMaterialsInWorkOrder;
		Items.GroupUseMaterialsInWorkOrder.Visible = True;
		Items.UseMaterialsInWorkOrder.Visible = True;
	Else
		Items.GroupUseMaterialsInWorkOrder.Visible = False;
		Items.UseMaterialsInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("UsePerformerSalariesInWorkOrder") Then
		UsePerformerSalariesInWorkOrder = Parameters.UsePerformerSalariesInWorkOrder;
		UsePerformerSalariesInWorkOrderOnOpen = Parameters.UsePerformerSalariesInWorkOrder;
		Items.GroupUsePerformerSalariesInWorkOrder.Visible = True;
		Items.UsePerformerSalariesInWorkOrder.Visible = True;
	Else
		Items.GroupUsePerformerSalariesInWorkOrder.Visible = False;
		Items.UsePerformerSalariesInWorkOrder.Visible = False;
	EndIf;
	
	If Parameters.Property("PositionAssignee") Then
		PositionAssignee = Parameters.PositionAssignee;
		PositionAssigneeOnOpen = Parameters.PositionAssignee;
		Items.GroupPositionAssignee.Visible = True;
		Items.PositionAssignee.Visible = True;
	Else
		Items.GroupPositionAssignee.Visible = False;
		Items.PositionAssignee.Visible = False;
	EndIf;
	
	If Parameters.Property("PositionResponsible") Then
		PositionResponsible = Parameters.PositionResponsible;
		LocationLocationResponsibleOnOpen = Parameters.PositionResponsible;
		Items.GroupPositionResponsible.Visible = True;
		Items.PositionResponsible.Visible = True;
	Else
		Items.GroupPositionResponsible.Visible = False;
		Items.PositionResponsible.Visible = False;
	EndIf;
	
	If Parameters.Property("InventoryStructuralUnitPositionInWIP") Then
		InventoryStructuralUnitPositionInWIP = Parameters.InventoryStructuralUnitPositionInWIP;
		InventoryStructuralUnitPositionInWIPOnOpen = Parameters.InventoryStructuralUnitPositionInWIP;
		Items.GroupInventoryStructuralUnitPositionInWIP.Visible = True;
		Items.InventoryStructuralUnitPositionInWIP.Visible = True;
	Else
		Items.GroupInventoryStructuralUnitPositionInWIP.Visible = False;
		Items.InventoryStructuralUnitPositionInWIP.Visible = False;
	EndIf;
	
	If Parameters.Property("RenameSalesOrderPositionInShipmentDocuments") Then
		Items.SalesOrderPositionInShipmentDocuments.Title = Parameters.RenameSalesOrderPositionInShipmentDocuments; 
	EndIf;
		
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure OK(Command)
	
	StructureOfFormAttributes = New Structure;
	
	CheckIfFormWasModified(StructureOfFormAttributes);
	
	Close(StructureOfFormAttributes);
	
EndProcedure

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure RememberSelection(Command)
	
	StructureOfFormAttributes = New Structure;
	
	CheckIfFormWasModified(StructureOfFormAttributes);
	
	WriteNewSettings();
	
	Close(StructureOfFormAttributes);
	
EndProcedure

#EndRegion
