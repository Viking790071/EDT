#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	CheckFunctionalOptions();
	
	If ThisObject.Parameters.Property("StructuralUnitType") Then
	
		Object.StructuralUnitType = ThisObject.Parameters.StructuralUnitType;
	
	EndIf; 

	TypeOfStructuralUnitRetail = Enums.BusinessUnitsTypes.Retail;
	TypeOfStructuralUnitRetailAmmountAccounting = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	TypeOfStructuralUnitWarehouse = Enums.BusinessUnitsTypes.Warehouse;

	Items.RetailPriceKind.Visible = (
		Object.StructuralUnitType = TypeOfStructuralUnitRetail
		OR Object.StructuralUnitType = TypeOfStructuralUnitWarehouse
		OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting);
		
	If Parameters.FilterUnitType = "" Then
		
		If Constants.UseSeveralWarehouses.Get()
			OR Object.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse Then
			Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Warehouse);
			If Constants.UseRetail.Get() 
				OR Object.StructuralUnitType = Enums.BusinessUnitsTypes.Retail 
				OR Object.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
				Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Retail);
				Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
			EndIf;
		EndIf;
		
		If Constants.UseSeveralDepartments.Get()
			OR Object.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
			Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Department);
		EndIf;
		
		If Not ValueIsFilled(Object.Ref)
			AND Items.StructuralUnitType.ChoiceList.Count() = 1 Then
			Object.StructuralUnitType = Items.StructuralUnitType.ChoiceList[0].Value;
		EndIf;
		
	ElsIf Parameters.FilterUnitType = "Department" Then
		
		Items.StructuralUnitType.Visible = False;
		
	ElsIf Parameters.FilterUnitType = "Warehouse" Then
		
		If Constants.UseSeveralWarehouses.Get() Then
			
			Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Warehouse);
			
			If Constants.UseRetail.Get() Then
				
				Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Retail);
				Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
				
			EndIf;
			
		EndIf;
		
	ElsIf Parameters.FilterUnitType = "BusinessUnits" Then
		
		If Constants.UseSeveralDepartments.Get() Then
			Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Department);
		EndIf;
		
		If Constants.UseSeveralWarehouses.Get() Then
			
			Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Warehouse);
			
			If Constants.UseRetail.Get() Then
				
				Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.Retail);
				Items.StructuralUnitType.ChoiceList.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Not GetFunctionalOption("UseDataSynchronization") Then
		Items.Company.Visible = False;
	EndIf;
	
	If GetFunctionalOption("UseCustomizableNumbering") Then
		Numbering.ShowNumberingIndex(ThisObject);
	EndIf;
	
	Items.RetailPriceKind.AutoMarkIncomplete = (
		Object.StructuralUnitType = TypeOfStructuralUnitRetail
		OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting);
		
	Items.PlanningGroup.Visible = 
			(Object.StructuralUnitType = Enums.BusinessUnitsTypes.Department);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnCreateAtServer(ThisObject, Object, "ContactInformationGroup", FormItemTitleLocation.Left);
	// End StandardSubsystems.ContactInformation
		
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	UpdateTitle();
	
	SetPlanningIntervalDurationVisible();
	FillPlanningIntervalString();
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
	 UpdateAdditionalAttributeItems();
	 PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	If EventName = "AccountsChangedBusinessUnits" Then
		Object.GLAccountInRetail = Parameter.GLAccountInRetail;
		Object.MarkupGLAccount = Parameter.MarkupGLAccount;
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactsManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactsManager.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	UpdateTitle();
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	// StandardSubsystems.ContactInformation
	ContactsManager.AfterWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
	Numbering.WriteNumberingIndex(ThisObject);
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure StructuralUnitTypeOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnitType) Then
		
		Items.RetailPriceKind.Visible = (
			Object.StructuralUnitType = TypeOfStructuralUnitRetail
			OR Object.StructuralUnitType = TypeOfStructuralUnitWarehouse
			OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting);
		
		Items.RetailPriceKind.MarkIncomplete = (
			Object.StructuralUnitType = TypeOfStructuralUnitRetail
			OR Object.StructuralUnitType = TypeOfStructuralUnitRetailAmmountAccounting);
			
		Items.PlanningGroup.Visible = 
			(Object.StructuralUnitType = PredefinedValue("Enum.BusinessUnitsTypes.Department"));
		
		UpdateTitle();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryAutotransferClick(Item)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("TransferSource", Object.TransferSource);
	ParametersStructure.Insert("TransferRecipient", Object.TransferRecipient);
	ParametersStructure.Insert("RecipientOfWastes", Object.RecipientOfWastes);
	ParametersStructure.Insert("WriteOffToExpensesSource", Object.WriteOffToExpensesSource);
	ParametersStructure.Insert("WriteOffToExpensesRecipient", Object.WriteOffToExpensesRecipient);
	ParametersStructure.Insert("PassToOperationSource", Object.PassToOperationSource);
	ParametersStructure.Insert("PassToOperationRecipient", Object.PassToOperationRecipient);
	ParametersStructure.Insert("ReturnFromOperationSource", Object.ReturnFromOperationSource);
	ParametersStructure.Insert("ReturnFromOperationRecipient", Object.ReturnFromOperationRecipient);
	
	ParametersStructure.Insert("TransferSourceCell", Object.TransferSourceCell);
	ParametersStructure.Insert("TransferRecipientCell", Object.TransferRecipientCell);
	ParametersStructure.Insert("DisposalsRecipientCell", Object.DisposalsRecipientCell);
	ParametersStructure.Insert("WriteOffToExpensesSourceCell", Object.WriteOffToExpensesSourceCell);
	ParametersStructure.Insert("WriteOffToExpensesRecipientCell", Object.WriteOffToExpensesRecipientCell);
	ParametersStructure.Insert("PassToOperationSourceCell", Object.PassToOperationSourceCell);
	ParametersStructure.Insert("PassToOperationRecipientCell", Object.PassToOperationRecipientCell);
	ParametersStructure.Insert("ReturnFromOperationSourceCell", Object.ReturnFromOperationSourceCell);
	ParametersStructure.Insert("ReturnFromOperationRecipientCell", Object.ReturnFromOperationRecipientCell);
	
	ParametersStructure.Insert("StructuralUnitType", Object.StructuralUnitType);
	
	Notification = New NotifyDescription("AutomovementocksEndClick",ThisForm);
	OpenForm("CommonForm.DefaultRecipientBusinessUnits", ParametersStructure,,,,,Notification);
	
	
EndProcedure

&AtClient
Procedure RetailPriceKindOnChange(Item)
	
	If Not ValueIsFilled(Object.RetailPriceKind) Then
		Return;
	EndIf;
	
	DataStructure = GetRetailPriceKindData(Object.RetailPriceKind);
	
	If Not DataStructure.PriceCurrency = DataStructure.FunctionalCurrency Then
		
		MessageText = NStr("en = 'Specify functional currency (%1) for the ""%2"" price type for retail business unit.'; ru = 'У типа цен ""%2"", для розничной структурной единицы, должна быть задана функциональная валюта (%1).';pl = 'Określ walutę funkcjonalną (%1) dla rodzaju ceny ""%2"" dla detalicznej jednostki biznesowej.';es_ES = 'Especifique la moneda funcional (%1) para el tipo de precio ""%2"" para la unidad de negocio minorista.';es_CO = 'Especifique la moneda funcional (%1) para el tipo de precio ""%2"" para la unidad de negocio minorista.';tr = 'Perakende departmanı için ""%2"" fiyat türünün fonksiyonel para birimini (%1) belirtin.';it = 'Indicare valuta funzionale (%1) per il tipo di prezzo ""%2"" per la business unit di vendita al dettaglio.';de = 'Geben Sie die funktionale Währung (%1) für den Preistyp ""%2"" für die Abteilung Einzelhandel an.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
			DataStructure.PriceKindDescription,
			DataStructure.FunctionalCurrency);
		
		CommonClientServer.MessageToUser(MessageText, , "Object.RetailPriceKind");
		
		Object.RetailPriceKind = Undefined;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure PlanningIntervalOnChange(Item)
	
	If Object.PlanningInterval <> PredefinedValue("Enum.PlanningIntervals.Minute") Then
		Object.PlanningIntervalDuration = 0;
	EndIf;
	
	SetPlanningIntervalDurationVisible();
	FillPlanningIntervalString();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function GetRetailPriceKindData(RetailPriceKind)
	
	DataStructure	 = New Structure;
	
	DataStructure.Insert("PriceKindDescription",	RetailPriceKind.Description);
	DataStructure.Insert("PriceCurrency", 			RetailPriceKind.PriceCurrency);
	DataStructure.Insert("FunctionalCurrency",		DriveReUse.GetFunctionalCurrency());
	
	Return DataStructure;
	
EndFunction

&AtClient
Procedure AutomovementocksEndClick(FillingParameters,Parameters) Export
	
	If TypeOf(FillingParameters) = Type("Structure") Then
		
		FillPropertyValues(Object, FillingParameters);
		
		If Not Modified 
			AND FillingParameters.Modified Then
			
			Modified = True;
			
		EndIf;
		
	EndIf;

	
EndProcedure

&AtServer
Procedure CheckFunctionalOptions()
	
	TypeOfStructuralUnitDepartment = Enums.BusinessUnitsTypes.Department;
	
	If Not ValueIsFilled(Object.Ref)
		And Object.StructuralUnitType = TypeOfStructuralUnitDepartment 
		And Not GetFunctionalOption("UseSeveralDepartments") Then
		ErrorText = NStr("en = 'It is forbidden to create new business unit
							|with the off parameter setting accounting ""Use several departments""'; 
							|ru = 'Запрещено создавать новую структурную единицу
							|при выключенной настройке параметра учета ""Учет по нескольким подразделениям"".';
							|pl = 'Zakazane jest tworzenie nowej jednostki biznesowej
							|z zakazem ustawienia parametru ""Używaj kilku działów""';
							|es_ES = 'Está prohibido crear una nueva unidad empresarial
							| con la configuración del parámetro de la contabilidad ""Usar varios departamentos"".';
							|es_CO = 'Está prohibido crear una nueva unidad empresarial
							| con la configuración del parámetro de la contabilidad ""Usar varios departamentos"".';
							|tr = '""Birkaç iş yeri kullan"" adlı kapalı parametre ayarı ile
							|yeni departman oluşturmak yasaktır.';
							|it = 'E'' vietata la creazione di nuove business unit
							|nel caso in cui non sia selezionata l''opzione contabile ""Utilizza più reparti""';
							|de = 'Es ist verboten, eine neue Abteilung
							|zu erstellen, wenn die Einstellung des Buchhaltungsparameters ""Mehrere Abteilungen verwenden"" deaktiviert ist'");
		Raise ErrorText;
		
	ElsIf Not ValueIsFilled(Object.Ref)
		And Object.StructuralUnitType <> TypeOfStructuralUnitDepartment 
		And Not GetFunctionalOption("UseSeveralWarehouses") Then
		
		ErrorText = NStr("en = 'It is forbidden to create new business unit
							|with the off parameter setting accounting ""Use several warehouses""'; 
							|ru = 'Запрещено создавать новую структурную единицу
							|при выключенной настройке параметра учета ""Учет по нескольким складам"".';
							|pl = 'Zakazane jest tworzenie nowej jednostki biznesowej
							|z zakazem ustawienia parametru ""Używaj kilku magazynów""';
							|es_ES = 'Está prohibido crear una nueva unidad empresarial
							| con la configuración del parámetro de la contabilidad ""Usar varios almacenes "".';
							|es_CO = 'Está prohibido crear una nueva unidad empresarial
							| con la configuración del parámetro de la contabilidad ""Usar varios almacenes "".';
							|tr = '""Birden fazla ambar kullan"" parametre ayarı kapalıyken
							|yeni departman oluşturulamaz';
							|it = 'E'' vietata la creazione di una business unit
							|nel caso in cui non sia selezionata l''impostazione contabile ""Utilizza più magazzini""';
							|de = 'Es ist verboten, eine neue Abteilung
							|zu erstellen, wenn die Einstellung des Buchhaltungsparameters ""Mehrere Lager verwenden"" deaktiviert ist'");
		Raise ErrorText;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateTitle()
	
	If Object.StructuralUnitType <> PredefinedValue("Enum.BusinessUnitsTypes.Department") Then
		
		AutoTitle = False;
		
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 (%2)'; ru = '%1 (%2)';pl = '%1 (%2)';es_ES = '%1 (%2)';es_CO = '%1 (%2)';tr = '%1 (%2)';it = '%1 (%2)';de = '%1 (%2)'"),
				Object.Description,
				NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
		Else
			Title = NStr("en = 'Warehouse (Create)'; ru = 'Склад (создание)';pl = 'Magazyn (Tworzenie)';es_ES = 'Almacén (Crear)';es_CO = 'Almacén (Crear)';tr = 'Ambar (Oluştur)';it = 'Magazzino (Crea)';de = 'Lager (erstellen)'");
		EndIf;
		
	Else
		
		AutoTitle = False;
		
		If ValueIsFilled(Object.Ref) Then
			Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 (%2)'; ru = '%1 (%2)';pl = '%1 (%2)';es_ES = '%1 (%2)';es_CO = '%1 (%2)';tr = '%1 (%2)';it = '%1 (%2)';de = '%1 (%2)'"),
				Object.Description,
				NStr("en = 'Department'; ru = 'Подразделение';pl = 'Dział';es_ES = 'Departamento';es_CO = 'Departamento';tr = 'Bölüm';it = 'Reparto';de = 'Abteilung'"));
		Else
			Title = NStr("en = 'Department (Create)'; ru = 'Подразделение (создание)';pl = 'Dział (Tworzenie)';es_ES = 'Departamento (Crear)';es_CO = 'Departamento (Crear)';tr = 'Bölüm (Oluştur)';it = 'Reparto (Crea)';de = 'Abteilung (erstellen)'");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetPlanningIntervalDurationVisible()
	
	Items.PlanningIntervalDuration.Visible = (Object.PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Minute"));
	Items.PlanningIntervalDuration.ReadOnly = Items.PlanningInterval.ReadOnly;
	Items.PlanningIntervalString.Visible = (Object.PlanningInterval <> PredefinedValue("Enum.PlanningIntervals.Minute"));
	
EndProcedure

&AtClient
Procedure FillPlanningIntervalString()
	
	PlanningIntervalString = "";
	
	If ValueIsFilled(Object.PlanningInterval) And Object.PlanningIntervalDuration = 0 Then
		
		PlanningIntervalString = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '1 %1'; ru = '1 %1';pl = '1 %1';es_ES = '1 %1';es_CO = '1 %1';tr = '1 %1';it = '1 %1';de = '1 %1'"),
			Object.PlanningInterval);
		
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

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

// StandardSubsystems.ContactInformation

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	ContactsManagerClient.OnChange(ThisObject, Item);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	ContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnClick(Item, StandardProcessing)
	ContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	ContactsManagerClient.Clearing(ThisObject, Item.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	ContactsManagerClient.ExecuteCommand(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	ContactsManagerClient.AutoComplete(Text, ChoiceData, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationChoiceProcessing(Item, SelectedValue, StandardProcessing)
	ContactsManagerClient.ChoiceProcessing(ThisObject, SelectedValue, Item.Name, StandardProcessing);
EndProcedure

&AtServer
Procedure Attachable_UpdateContactInformation(Result) Export
	ContactsManager.UpdateContactInformation(ThisObject, Object, Result);
EndProcedure

// End StandardSubsystems.ContactInformation

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion
