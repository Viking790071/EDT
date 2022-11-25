#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ContractsListByDefault = GetContractsByDefault();
	
	If ContractsListByDefault.Count() > 0 Then
		
		SetAppearanceOfContractsByDefault(ContractsListByDefault);
		
	EndIf;
	
	DoOperationsByContracts = True;
	CounterpartyFilter = Undefined;
	If Parameters.Filter.Property("Owner", CounterpartyFilter) Then
		If ValueIsFilled(CounterpartyFilter) Then
			DoOperationsByContracts = Common.ObjectAttributeValue(CounterpartyFilter, "DoOperationsByContracts");
		EndIf;
	EndIf;
	
	If Not DoOperationsByContracts Then
		EmptyContract = PredefinedValue("Catalog.CounterpartyContracts.EmptyRef");
		CommonClientServer.SetDynamicListFilterItem(List, "Ref", EmptyContract, DataCompositionComparisonType.Equal, "EmptyRef", True);	
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If NOT DoOperationsByContracts Then
		MessageText = NStr("en = 'Cannot create the contract because billing details by contract are turned off for the selected counterparty.
			| Turn them on in the counterparty details and then try again.'; 
			|ru = 'Не удалось создать договор. По указанному контрагенту не ведется учет взаиморасчетов по договорам.
			|Включите взаиморасчеты по договорам и попробуйте снова.';
			|pl = 'Nie można utworzyć umowy, ponieważ szczegóły fakturowania są wyłączone dla wybranego kontrahenta. 
			| Włącz je w danych o kontrahencie, a następnie spróbuj ponownie.';
			|es_ES = 'No se puede crear el contrato porque los detalles de facturación por el contrato están desactivados para la contraparte seleccionada. 
			|Active los detalles de la contraparte e inténtelo de nuevo.';
			|es_CO = 'No se puede crear el contrato porque los detalles de facturación por el contrato están desactivados para la contraparte seleccionada. 
			|Active los detalles de la contraparte e inténtelo de nuevo.';
			|tr = 'Seçili cari hesap için fatura ayrıntıları kapalı olduğundan sözleşme oluşturulamıyor.
			| Cari hesap ayrıntılarında bunları açıp tekrar deneyin.';
			|it = 'Impossibile creare il contratto perché i dettagli di fatturazione per contratto sono disattivati per la controparte selezionata.
			| Attivarli nei dettagli della controparte e riprovare.';
			|de = 'Der Vertrag kann nicht erstellt werden, da die Abrechnungsdetails nach Vertrag für den ausgewählten Geschäftspartner deaktiviert sind.
			|Schalten Sie sie in den Geschäftspartnerdetails ein und versuchen Sie es dann erneut.'");
		CommonClientServer.MessageToUser(MessageText, , , ,Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtServerNoContext
// Function receives and returns the selection of default contracts 
// 
// ArrayCounterparty - array of counterparties for which it is necessary to select the default contracts.
//
Function GetContractsByDefault(ArrayCounterparty = Undefined)
	
	Query			= New Query;
	
	Query.Text	=
	"SELECT ALLOWED
	|	Counterparties.ContractByDefault AS Contract
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	(NOT Counterparties.IsFolder)
	|	AND (NOT Counterparties.ContractByDefault = VALUE(Catalog.CounterpartyContracts.EmptyRef))
	|	AND &FilterConditionByCounterparties";
	
	
	Query.Text = StrReplace(Query.Text, 
		"&FilterConditionByCounterparties",
		?(TypeOf(ArrayCounterparty) = Type("Array"), "Counterparties.Ref IN (&ArrayCounterparty)", "True"));
	
	QueryResult			= Query.Execute().Unload();
	
	ContractsListByDefault	= New ValueList;
	ContractsListByDefault.LoadValues(QueryResult.UnloadColumn("Contract"));
	
	Return ContractsListByDefault;
	
EndFunction

&AtServer
// Procedure marks the contracts by default in the list
//
Procedure SetAppearanceOfContractsByDefault(ContractsListByDefault)
	
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	
	ConditionalAppearanceItemsOfList	= List.SettingsComposer.Settings.ConditionalAppearance.Items;
	ConditionalAppearanceItem			= ConditionalAppearanceItemsOfList.Add();
	
	FilterItem 						= ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue 		= New DataCompositionField("Ref");
	FilterItem.ComparisonType 			= DataCompositionComparisonType.InList;
	FilterItem.RightValue 		= ContractsListByDefault;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,,True,));
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "Preset";
	ConditionalAppearanceItem.Presentation = "Contracts by default";  
	
EndProcedure

&AtClient
// Procedure sets the current record as a default Contract for the owner
//
Procedure SetAsContractByDefault(Command)
	
	ContractsListByDefault = New ValueList;
	
	CurrentListRow = Items.List.CurrentData;
	
	If CurrentListRow = Undefined Then
		
		MessageText = NStr("en = 'Select the default contract.'; ru = 'Не выбран договор, который необходимо установить как Договор по умолчанию';pl = 'Wybierz umowę domyślną';es_ES = 'Seleccionar el contrato por defecto.';es_CO = 'Seleccionar el contrato por defecto.';tr = 'Varsayılan sözleşmeyi seçin.';it = 'Selezionate il contratto predefinito.';de = 'Wählen Sie den Standardvertrag aus.'");
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	NewContractByDefault	= CurrentListRow.Ref;
	Counterparty				= CurrentListRow.Owner;
	
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset" AND
			ConditionalAppearanceItem.Presentation = "Contracts by default" Then
			
			FilterItem				= ConditionalAppearanceItem.Filter.Items[0];
			ContractsListByDefault	= FilterItem.RightValue;
			
		EndIf;
	EndDo;
	
	If Not ContractsListByDefault.FindByValue(NewContractByDefault) = Undefined Then
		
		Return;
		
	EndIf;
	
	ChangeCardOfCounterpartyAndChangeListAppearance(Counterparty, NewContractByDefault, ContractsListByDefault);
	
	Notify("RereadContractByDefault");
	
EndProcedure

&AtServer
// Procedure - writes new value in
// counterparty card and updates the visual presentation of the contract by default in the list form
//
Procedure ChangeCardOfCounterpartyAndChangeListAppearance(Counterparty, NewContractByDefault, ContractsListByDefault)
	
	CounterpartyObject 						= Counterparty.GetObject();
	OldContractByDefault				= CounterpartyObject.ContractByDefault;
	CounterpartyObject.ContractByDefault		= NewContractByDefault;
	
	Try
		
		CounterpartyObject.Write();
		
	Except
		
		MessageText = NStr("en = 'Cannot change the default contract in the counterparty details. Close all windows and try again.'; ru = 'Не удалось поменять договор по умолчанию в карточке контрагента.';pl = 'Nie można zmienić domyślnej umowy w danych o kontrahencie. Zamknij wszystkie okna i spróbuj ponownie.';es_ES = 'No se puede cambiar el contrato por defecto en los detalles de la contraparte. Cerrar todas las ventanas e intentar de nuevo.';es_CO = 'No se puede cambiar el contrato por defecto en los detalles de la contraparte. Cerrar todas las ventanas e intentar de nuevo.';tr = 'Cari hesap ayrıntılarında varsayılan sözleşme değiştirilemez. Tüm pencereleri kapatın ve tekrar deneyin.';it = 'Non è possibile cambiare il contratto predefinito nella scheda della controparte. Chiudere tutte le finistre e provare nuovamente.';de = 'Der Standardvertrag kann in den Geschäftspartnerdetails nicht geändert werden. Schließen Sie alle Fenster und versuchen Sie es erneut.'");
		CommonClientServer.MessageToUser(MessageText);
		
	EndTry;
	
	ValueListItem 					= ContractsListByDefault.FindByValue(OldContractByDefault);
	
	If Not ValueListItem = Undefined Then
		
		ContractsListByDefault.Delete(ValueListItem);
		
	EndIf;
	
	ContractsListByDefault.Add(NewContractByDefault);
	
	SetAppearanceOfContractsByDefault(ContractsListByDefault);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion
