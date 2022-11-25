#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		OnCreateOnReadAtServer();
		
	EndIf;
	
	ProcessingCompanyVATNumbers();
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(
		Metadata.Documents.SalesTarget.TabularSections.Inventory,
		DataLoadSettings,
		ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	OnCreateOnReadAtServer();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	FillTableFromSalesTargetTable(CurrentObject.Inventory);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	For Each TableRow In SalesTargetTable Do
		
		For Each Dimension In SalesGoalSettingAttributes.Dimensions Do
			
			If Not ValueIsFilled(TableRow[Dimension]) Then
				
				ErrorText = CommonClientServer.FillingErrorText(
					"Column",
					"FILLTYPE",
					Dimension,
					TableRow.LineNumber,
					Items.PageTarget.Title);
				
				CommonClientServer.MessageToUser(
					ErrorText,
					,
					CommonClientServer.PathToTabularSection("SalesTargetTable", TableRow.LineNumber, Dimension),
					,
					Cancel);
				
			EndIf;
			
		EndDo;
		
		If SalesGoalSettingAttributes.SpecifyQuantity Then
			
			If Not ValueIsFilled(TableRow.TotalQuantity) Then
				
				ErrorText = CommonClientServer.FillingErrorText(
					"Column",
					"FILLTYPE",
					NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"),
					TableRow.LineNumber,
					Items.PageTarget.Title);
				
				CommonClientServer.MessageToUser(
					ErrorText,
					,
					CommonClientServer.PathToTabularSection("SalesTargetTable", TableRow.LineNumber, "ColumnQuantity_0"),
					,
					Cancel);
				
			EndIf;
			
			If Not ValueIsFilled(TableRow.MeasurementUnit) Then
				
				ErrorText = CommonClientServer.FillingErrorText(
					"Column",
					"FILLTYPE",
					NStr("en = 'Unit of measurement'; ru = 'Единица измерения';pl = 'Jednostka miary';es_ES = 'Unidad de medida';es_CO = 'Unidad de medida';tr = 'Ölçü birimi';it = 'Unità di misura';de = 'Maßeinheit'"),
					TableRow.LineNumber,
					Items.PageTarget.Title);
				
				CommonClientServer.MessageToUser(
				ErrorText,
				,
				CommonClientServer.PathToTabularSection("SalesTargetTable", TableRow.LineNumber, "MeasurementUnit"),
				,
				Cancel);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SalesGoalSettingOnChange(Item)
	
	If SalesTargetTable.Count() > 0 And ValueIsFilled(AttributesStartValues.SalesGoalSetting) Then
		
		NotifyDescription = New NotifyDescription("AskChangeSalesGoalSetting", ThisObject);
		QuestionText = NStr("en = 'On the Target tab, the current sales target dimensions 
			|will be replaced with the dimensions of
			|the selected sales target type. 
			|Do you want to continue?'; 
			|ru = 'Во вкладке ""Цель"" текущие целевые измерения продаж 
			|будут заменены измерениями
			|выбранного типа целей продаж. 
			|Продолжить?';
			|pl = 'Na karcie Cel, bieżące wymiary docelowe sprzedaży 
			|zostaną zastąpione wymiarami 
			|wybranego typu docelowego sprzedaży. 
			|Czy chcesz kontynuować?';
			|es_ES = 'En la pestaña Objetivo, las dimensiones actuales del objetivo de ventas
			|serán reemplazadas por las dimensiones del
			| tipo de objetivo de ventas seleccionado.
			| ¿Quiere continuar?';
			|es_CO = 'En la pestaña Objetivo, las dimensiones actuales del objetivo de ventas
			|serán reemplazadas por las dimensiones del
			| tipo de objetivo de ventas seleccionado.
			| ¿Quiere continuar?';
			|tr = 'Hedef sekmesinde, 
			|mevcut satış hedefi boyutları 
			|seçili satış hedefi türünün boyutlarıyla değiştirilecek. 
			|Devam etmek istiyor musunuz?';
			|it = 'Nella scheda Target, la dimensione del target di vendita corrente 
			|sarà sostituito con le dimensioni del
			| tipo di target di vendita selezionato.
			| Continuare?';
			|de = 'Auf der Registerkarte Ziel werden die aktuellen Abmessungen des Umsatzziels 
			|durch die Abmessungen 
			|des ausgewählten Umsatzzieltyps ersetzt. 
			|Möchten Sie fortfahren?'");
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.Title = NStr("en = 'Sales goal setting changing'; ru = 'Изменение настройки плана продаж';pl = 'Zmiana ustawień celu sprzedaży';es_ES = 'Configuración de los objetivos de ventas';es_CO = 'Configuración de los objetivos de ventas';tr = 'Satış hedefi ayarlarını değiştirme';it = 'Modifica impostazioni obiettivi di vendita';de = 'Verkaufszielsetzung ändern'");
		QuestionParameters.DoNotAskAgain = False;
		StandardSubsystemsClient.ShowQuestionToUser(
			NotifyDescription,
			QuestionText,
			QuestionDialogMode.YesNo,
			QuestionParameters);
		
	Else
		
		OnChangeSalesGoalSettingAtServer();
		FormManagement();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodStartDateOnChange(Item)
	
	PeriodOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure PeriodEndDateOnChange(Item)
	
	PeriodOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	ParentCompany = Object.Company;
	
	ProcessingCompanyVATNumbers(False);
		
EndProcedure

&AtClient
Procedure PricesAndCurrencyClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ReadOnly",			ThisObject.ReadOnly);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	ParametersStructure.Insert("RefillPrices",		False);
	ParametersStructure.Insert("RecalculatePrices",	False);
	ParametersStructure.Insert("WereMadeChanges",	False);
	
	If SalesGoalSettingAttributes.SpecifyQuantity Then
		ParametersStructure.Insert("PriceKind", Object.PriceKind);
	EndIf;
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure,
		ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

#EndRegion

#Region SalesTargetTableFormTableItemsEventHandlers

&AtClient
Procedure SalesTargetTableOnChange(Item)
	
	FillLineNumbers(ThisObject);
	CalculateRowsQuantity(ThisObject);
	RecalculateSubtotal(ThisObject);
	
EndProcedure

&AtClient
Procedure SalesTargetTableOnEditEnd(Item, NewRow, CancelEdit)
	
	CalculateRowsQuantity(ThisObject);
	RecalculateSubtotal(ThisObject);
	
EndProcedure

&AtClient
Procedure SalesTargetTableAfterDeleteRow(Item)
	
	FillLineNumbers(ThisObject);
	CalculateRowsQuantity(ThisObject);
	RecalculateSubtotal(ThisObject);
	
EndProcedure

&AtClient
Procedure SalesTargetTableProductsOnChange(Item)
	
	TabularSectionRow = Items.SalesTargetTable.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	
	If SalesGoalSettingAttributes.SpecifyQuantity Then
		
		CalculateRowAmount(TabularSectionRow, Periods);
		CalculateRowTotals(TabularSectionRow, Periods);
		RecalculateSubtotal(ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SalesTargetTableCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.SalesTargetTable.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "SalesTargetTable";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, True);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SalesTargetTableCharacteristicOnChange(Item)
	
	If SalesGoalSettingAttributes.SpecifyQuantity Then
		
		TabularSectionRow = Items.SalesTargetTable.CurrentData;
		
		StructureData = New Structure;
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Products", TabularSectionRow.Products);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		
		If ValueIsFilled(Object.PriceKind) Then
			
			StructureData.Insert("ProcessingDate", Object.Date);
			StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
			StructureData.Insert("PriceKind", Object.PriceKind);
			StructureData.Insert("Factor", 1);
			
		EndIf;
		
		StructureData = GetDataProductsOnChange(StructureData);
		
		FillPropertyValues(TabularSectionRow, StructureData); 
		
		CalculateRowAmount(TabularSectionRow, Periods);
		CalculateRowTotals(TabularSectionRow, Periods);
		RecalculateSubtotal(ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SalesTargetTablePriceOnChange(Item)
	
	TabularSectionRow = Items.SalesTargetTable.CurrentData;
	
	CalculateRowAmount(TabularSectionRow, Periods);
	CalculateRowTotals(TabularSectionRow, Periods);
	RecalculateSubtotal(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_ColumnQuantityOnChange(Item)
	
	TabularSectionRow = Items.SalesTargetTable.CurrentData;
	
	Index = Mid(Item.Name, StrLen("ColumnQuantity_") + 1);
	TabularSectionRow["ColumnAmount_" + Index] = TabularSectionRow["ColumnQuantity_" + Index] * TabularSectionRow.Price;
	
	CalculateRowTotals(TabularSectionRow, Periods);
	RecalculateSubtotal(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_ColumnAmountOnChange(Item)
	
	TabularSectionRow = Items.SalesTargetTable.CurrentData;
	
	CalculateRowTotals(TabularSectionRow, Periods);
	RecalculateSubtotal(ThisObject);
	
	If SalesGoalSettingAttributes.SpecifyQuantity And TabularSectionRow.TotalQuantity Then
		TabularSectionRow.Price = TabularSectionRow.TotalAmount / TabularSectionRow.TotalQuantity;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SetPeriod(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate	= Object.PeriodStartDate;
	Dialog.Period.EndDate	= Object.PeriodEndDate;
	
	NotifyDescription = New NotifyDescription("SetPeriodEnd", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure FillInByTargetSales(Command)
	
	OpenFillingSettings("Schema_SalesTarget", NStr("en = 'Fill-in by target sales'; ru = 'Заполнить по плану продаж';pl = 'Wypełnij według planu sprzedaży';es_ES = 'Rellenar por objetivos de ventas';es_CO = 'Rellenar por objetivos de ventas';tr = 'Hedef satışlara göre doldur';it = 'Compila secondo target di vendita';de = 'Ausfüllen nach Zielverkäufen'"));
	
EndProcedure

&AtClient
Procedure FillInByActualSales(Command)
	
	OpenFillingSettings("Schema_SalesActual", NStr("en = 'Fill-in by actual sales'; ru = 'Заполнить по факту продаж';pl = 'Wypełnij według faktycznej sprzedaży';es_ES = 'Rellenar por ventas reales';es_CO = 'Rellenar por ventas reales';tr = 'Gerçek satışlara göre doldur';it = 'Compila secondo consuntivo di vendita';de = 'Ausfüllen durch die tatsächlichen Verkäufe'"));
	
EndProcedure

&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "SalesTargetTable";
	DocumentPresentaion	= NStr("en = 'sales target'; ru = 'планы продаж';pl = 'plan sprzedaży';es_ES = 'objetivo de ventas';es_CO = 'objetivo de ventas';tr = 'satış hedefi';it = 'obiettivo di vendita';de = 'Verkaufsziel'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, False, True, False, False);
	SelectionParameters.Insert("Company", Object.Company);
	
	SelectionParameters.Insert("TotalItems", SalesTargetTable.Count());
	SelectionParameters.Insert("TotalAmount", TargetTotalAmount);
	
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure OnCreateOnReadAtServer()
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	ReadSalesGoalSettingAttributes(SalesGoalSettingAttributes, Object.SalesGoalSetting);
	FillAttributesStartValues(ThisObject);
	
	ChangeSalesTargetTableStructure();
	FillSalesTargetTableFromTable(Object.Inventory);
	
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtServerNoContext
Procedure ReadSalesGoalSettingAttributes(SalesGoalAttributes, Val ValueSalesGoal)
	
	Attributes = "Periodicity, SpecifyQuantity";
	If SalesGoalAttributes = Undefined Then
		SalesGoalAttributes = New Structure(Attributes);
		SalesGoalAttributes.Insert("Dimensions", New Array);
	EndIf;
	
	If ValueIsFilled(ValueSalesGoal) Then
		
		FillPropertyValues(SalesGoalAttributes, Common.ObjectAttributesValues(ValueSalesGoal, Attributes));
		
		SalesGoalAttributes.Dimensions.Clear();
		For Each DimensionRow In ValueSalesGoal.Dimensions Do
			SalesGoalAttributes.Dimensions.Add(XMLString(DimensionRow.Dimension));
		EndDo;
		
	Else
		
		SalesGoalAttributes.Periodicity = Enums.Periodicity.EmptyRef();
		SalesGoalAttributes.SpecifyQuantity = False;
		SalesGoalAttributes.Dimensions.Clear();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeSalesTargetTableStructure()
	
	AttributesToBeAdded = New Array;
	AttributesToBeDeleted = New Array;
	
	For Index = 0 To Periods.Count() - 1 Do
		PeriodColumnGroupName = "SalesTargetTablePeriod_" + Format(Index, "NZ=0; NG=0");
		Items.Delete(Items[PeriodColumnGroupName]);
	EndDo;
	
	SalesTargetAttributes = GetAttributes("SalesTargetTable");
	For Each SalesTargetAttribute In SalesTargetAttributes Do
		
		If StrStartsWith(SalesTargetAttribute.Name, "ColumnQuantity_")
			Or StrStartsWith(SalesTargetAttribute.Name, "ColumnAmount_") Then
			
			AttributesToBeDeleted.Add("SalesTargetTable." + SalesTargetAttribute.Name);
			
		EndIf;
		
	EndDo;
	
	PeriodsTable = FormAttributeToValue("Periods");
	FillPeriodsTable(PeriodsTable, Object.PeriodStartDate, Object.PeriodEndDate, SalesGoalSettingAttributes.Periodicity);
	ValueToFormAttribute(PeriodsTable, "Periods");
	
	Number_15_2 = Common.TypeDescriptionNumber(15, 2, AllowedSign.Nonnegative);
	Number_15_3 = Common.TypeDescriptionNumber(15, 3, AllowedSign.Nonnegative);
	
	For Index = 0 To Periods.Count() - 1 Do
		
		If SalesGoalSettingAttributes.SpecifyQuantity Then
			
			FormAttribute = New FormAttribute(
				"ColumnQuantity_" + Format(Index, "NZ=0; NG=0"),
				Number_15_3,
				"SalesTargetTable",
				NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"),
				True);
			AttributesToBeAdded.Add(FormAttribute);
			
		EndIf;
		
		FormAttribute = New FormAttribute(
			"ColumnAmount_" + Format(Index, "NZ=0; NG=0"),
			Number_15_2,
			"SalesTargetTable",
			NStr("en = 'Amount'; ru = 'Сумма';pl = 'Kwota';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'"),
			True);
		AttributesToBeAdded.Add(FormAttribute);
		
	EndDo;
	
	ChangeAttributes(AttributesToBeAdded, AttributesToBeDeleted);
	
	For Index = 0 To Periods.Count() - 1 Do
		
		ColumnGroup = Items.Add(
			"SalesTargetTablePeriod_" + Format(Index, "NZ=0; NG=0"),
			Type("FormGroup"),
			Items.SalesTargetTable);
		ColumnGroup.Type = FormGroupType.ColumnGroup;
		ColumnGroup.Group = ColumnsGroup.Horizontal;
		ColumnGroup.ShowInHeader = True;
		ColumnGroup.Title = Periods.Get(Index).ColumnTitle;
		
		If SalesGoalSettingAttributes.SpecifyQuantity Then
			
			NewAttribute = Items.Add(
				"ColumnQuantity_" + Format(Index, "NZ=0; NG=0"),
				Type("FormField"),
				ColumnGroup);
			NewAttribute.DataPath = "SalesTargetTable." + "ColumnQuantity_" + Format(Index, "NZ=0; NG=0");
			NewAttribute.Type = FormFieldType.InputField;
			NewAttribute.Width = 10;
			NewAttribute.SetAction("OnChange", "Attachable_ColumnQuantityOnChange");
			
		EndIf;
		
		NewAttribute = Items.Add(
			"ColumnAmount_" + Format(Index, "NZ=0; NG=0"),
			Type("FormField"),
			ColumnGroup);
		NewAttribute.DataPath = "SalesTargetTable." + "ColumnAmount_" + Format(Index, "NZ=0; NG=0");
		NewAttribute.Type = FormFieldType.InputField;
		NewAttribute.Width = 10;
		NewAttribute.ShowInHeader = SalesGoalSettingAttributes.SpecifyQuantity;
		NewAttribute.SetAction("OnChange", "Attachable_ColumnAmountOnChange");
		
	EndDo;
	
	Items.Move(Items.SalesTargetTableTotalQuantity, Items.SalesTargetTable);
	Items.Move(Items.SalesTargetTableTotalAmount, Items.SalesTargetTable);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillPeriodsTable(PeriodsTable, Val PeriodStartDate, Val PeriodEndDate, Val Periodicity)
	
	PeriodsTable.Clear();
	
	If ValueIsFilled(Periodicity) And ValueIsFilled(PeriodStartDate) And ValueIsFilled(PeriodEndDate) Then
		
		AddPeriodStartDate = SalesTargetingClientServer.CalculatePeriodStartDate(PeriodStartDate, Periodicity);
		AddPeriodEndDate = SalesTargetingClientServer.CalculatePeriodEndDate(PeriodStartDate, Periodicity);
		
		While AddPeriodStartDate < EndOfDay(PeriodEndDate) Do
			
			NewRow = PeriodsTable.Add();
			NewRow.PeriodStartDate = AddPeriodStartDate;
			NewRow.PeriodEndDate = AddPeriodEndDate;
			NewRow.ColumnTitle = SalesTargetingClientServer.SetPeriodTitle(AddPeriodStartDate, AddPeriodEndDate, Periodicity);
			
			AddPeriodStartDate = SalesTargetingClientServer.CalculatePeriodStartDate(AddPeriodEndDate + 1, Periodicity);
			AddPeriodEndDate = SalesTargetingClientServer.CalculatePeriodEndDate(AddPeriodEndDate + 1, Periodicity);
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateLabelPricesAndCurrency(Form)
	
	Object = Form.Object;
	
	LabelStructure = New Structure;
	LabelStructure.Insert("ForeignExchangeAccounting",	Form.ForeignExchangeAccounting);
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	
	If Form.SalesGoalSettingAttributes.SpecifyQuantity Then
		LabelStructure.Insert("PriceKind",				Object.PriceKind);
	EndIf;
	
	Form.PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	// Table columns visible
	For Each ChildItem In Items.SalesTargetTableDimensions.ChildItems Do
		ChildItem.Visible = False;
	EndDo;
	
	ItIsGoalByProducts = False;
	If ValueIsFilled(Object.SalesGoalSetting) Then
		
		For Each Dimension In SalesGoalSettingAttributes.Dimensions Do
			
			Items["SalesTargetTable" + Dimension].Visible = True;
			
			If Not ItIsGoalByProducts And Dimension = "Products" Then
				ItIsGoalByProducts = True;
			EndIf;
			
		EndDo;
		
	EndIf;
	Items.SalesTargetTableCharacteristic.Visible = Items.SalesTargetTableProducts.Visible;
	
	Items.SalesTargetTableTotalQuantity.Visible		= SalesGoalSettingAttributes.SpecifyQuantity;
	Items.SalesTargetTableMeasurementUnit.Visible	= SalesGoalSettingAttributes.SpecifyQuantity;
	Items.SalesTargetTablePrice.Visible				= SalesGoalSettingAttributes.SpecifyQuantity;
	
	// Header items visible
	Items.PricesAndCurrency.Visible = ForeignExchangeAccounting Or SalesGoalSettingAttributes.SpecifyQuantity;
	Items.SalesTargetTableInventoryPick.Visible = ItIsGoalByProducts;
	
EndProcedure

&AtServer
Procedure FillTableFromSalesTargetTable(Table)
	
	Table.Clear();
	
	For Each TableRow In SalesTargetTable Do
		
		For Index = 0 To Periods.Count() - 1 Do
			
			NewRow = Table.Add();
			FillPropertyValues(
				NewRow,
				TableRow,
				StrConcat(SalesGoalSettingAttributes.Dimensions, ",") + ", Characteristic, MeasurementUnit, Price");
				
			NewRow.PlanningDate = Periods.Get(Index).PeriodStartDate;
			NewRow.Amount = TableRow["ColumnAmount_" + Format(Index, "NZ=0; NG=0")];
			
			If SalesGoalSettingAttributes.SpecifyQuantity Then
				
				NewRow.Quantity = TableRow["ColumnQuantity_" + Format(Index, "NZ=0; NG=0")];
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillSalesTargetTableFromTable(Table, ClearBeforeFilling = True)
	
	If ClearBeforeFilling Then
		SalesTargetTable.Clear();
	EndIf;
	
	Filter = New Structure("PeriodStartDate");
	NewRow = Undefined;
	
	StrFillingProperties = StrConcat(SalesGoalSettingAttributes.Dimensions, ",") + ",Characteristic,MeasurementUnit,Price";
	FillingProperties = StrSplit(StrFillingProperties, ",", False);
	
	For Each TableRow In Table Do
		
		AddNewTableRow = False;
		
		If NewRow = Undefined Then
			AddNewTableRow = True;
		Else
			For Each Dimension In FillingProperties Do
				If TableRow[Dimension] <> NewRow[Dimension] Then
					AddNewTableRow = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If AddNewTableRow Then
			
			NewRow = SalesTargetTable.Add();
			FillPropertyValues(NewRow, TableRow, StrFillingProperties);
			
		EndIf;
		
		Filter.PeriodStartDate = TableRow.PlanningDate;
		FoundedRows = Periods.FindRows(Filter);
		
		If FoundedRows.Count() Then
			
			Index = Periods.IndexOf(FoundedRows[0]);
			NewRow["ColumnAmount_" + Format(Index, "NZ=0; NG=0")] = TableRow.Amount;
			
			If SalesGoalSettingAttributes.SpecifyQuantity Then
				
				NewRow["ColumnQuantity_" + Format(Index, "NZ=0; NG=0")] = TableRow.Quantity;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	FillLineNumbers(ThisObject);
	CalculateRowsQuantity(ThisObject);
	CalculateRowsTotals(ThisObject);
	
	If SalesGoalSettingAttributes.SpecifyQuantity Then
		For Each TableRow In SalesTargetTable Do
			If TableRow.TotalQuantity > 0 Then
				TableRow.Price = TableRow.TotalAmount / TableRow.TotalQuantity;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillAttributesStartValues(Form)
	
	Attributes = "SalesGoalSetting, PeriodStartDate, PeriodEndDate";
	If Form.AttributesStartValues = Undefined Then
		Form.AttributesStartValues = New Structure(Attributes);
	EndIf;
	
	FillPropertyValues(Form.AttributesStartValues, Form.Object, Attributes);
	
EndProcedure

&AtServer
Procedure OnChangeSalesGoalSettingAtServer()
	
	FillAttributesStartValues(ThisObject);
	ReadSalesGoalSettingAttributes(SalesGoalSettingAttributes, Object.SalesGoalSetting);
	ChangeSalesTargetTableStructure();
	GenerateLabelPricesAndCurrency(ThisObject);
	
EndProcedure

&AtServer
Procedure OnChangePeriodAtServer()
	
	FillAttributesStartValues(ThisObject);
	ChangeSalesTargetTableStructure();
	CalculateRowsTotals(ThisObject);
	
EndProcedure

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		EndIf;
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure FillSalesTarget(CalculationsResult)
	
	If IsTempStorageURL(CalculationsResult.ResultAddress) Then
		
		FillingTable = GetFromTempStorage(CalculationsResult.ResultAddress);
		FillSalesTargetTableFromTable(FillingTable, CalculationsResult.ClearBeforeFilling);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetExchangeRate(Company, PreviousCurrency, DocumentCurrency, Date)
	
	Return DriveServer.GetExchangeRate(Company, PreviousCurrency, DocumentCurrency, Date);
	
EndFunction

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure DateOnChangeAtServer()
	ProcessingCompanyVATNumbers();
EndProcedure

#Region WorkWithSelection

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = SalesTargetTable.Add();
		FillPropertyValues(NewRow, ImportRow);
		
		ProductCategoryIndex = SalesGoalSettingAttributes.Dimensions.Find("ProductCategory");
		
		If ProductCategoryIndex <> Undefined Then
			
			NewRow.ProductCategory = Common.ObjectAttributeValue(NewRow.Products, "ProductsCategory");
			
		EndIf;
		
		ProductGroupIndex = SalesGoalSettingAttributes.Dimensions.Find("ProductGroup");
		
		If ProductGroupIndex <> Undefined Then
			
			NewRow.ProductGroup = Common.ObjectAttributeValue(NewRow.Products, "Parent");
			
		EndIf;
		
		If SalesGoalSettingAttributes.SpecifyQuantity And Periods.Count() > 0 Then
			
			NewRow["ColumnAmount_0"] = ImportRow.Amount;
			NewRow["ColumnQuantity_0"] = ImportRow.Quantity;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True);
			
			FillLineNumbers(ThisObject);
			CalculateRowsQuantity(ThisObject);
			CalculateRowsTotals(ThisObject);
			RecalculateSubtotal(ThisObject);
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = SalesTargetTable.FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				SalesTargetTable.Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True);
			
			FillLineNumbers(ThisObject);
			CalculateRowsQuantity(ThisObject);
			CalculateRowsTotals(ThisObject);
			RecalculateSubtotal(ThisObject);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Calculations

&AtClientAtServerNoContext
Procedure FillLineNumbers(Form)
	
	RowNumber = 1;
	
	For Each TableRow In Form.SalesTargetTable Do
		
		TableRow.LineNumber = RowNumber;
		RowNumber = RowNumber + 1;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateRowsQuantity(Form)
	
	Form.PlanRowsQuantity = Form.SalesTargetTable.Count();
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateRowsTotals(Form)
	
	For Each TableRow In Form.SalesTargetTable Do
		
		CalculateRowTotals(TableRow, Form.Periods);
		
	EndDo;
	
	RecalculateSubtotal(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateRowTotals(TabularSectionRow, Periods)
	
	TabularSectionRow.TotalAmount = 0;
	TabularSectionRow.TotalQuantity = 0;
	
	For Index = 0 To Periods.Count() - 1 Do
		
		ColumnValue = 0;
		
		If TabularSectionRow.Property("ColumnQuantity_" + Format(Index, "NZ=0; NG=0"), ColumnValue) Then
			TabularSectionRow.TotalQuantity = TabularSectionRow.TotalQuantity + ColumnValue;
		EndIf;
		
		If TabularSectionRow.Property("ColumnAmount_" + Format(Index, "NZ=0; NG=0"), ColumnValue) Then
			TabularSectionRow.TotalAmount = TabularSectionRow.TotalAmount + ColumnValue;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateRowsAmount(Form)
	
	For Each TableRow In Form.SalesTargetTable Do
		
		CalculateRowAmount(TableRow, Form.Periods);
		
	EndDo;
	
	RecalculateSubtotal(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure CalculateRowAmount(TabularSectionRow, Periods)
	
	For Index = 0 To Periods.Count() - 1 Do
		
		TabularSectionRow["ColumnAmount_" + Format(Index, "NZ=0; NG=0")] =
			TabularSectionRow["ColumnQuantity_" + Format(Index, "NZ=0; NG=0")] * TabularSectionRow.Price;
			
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RecalculateSubtotal(Form)
	
	Form.TargetTotalAmount = Form.SalesTargetTable.Total("TotalAmount");
	
EndProcedure

Function GetExchangeRateMethod(Company)

	Return DriveServer.GetExchangeMethod(Company)

EndFunction 

&AtServer
Procedure RefillTabularSectionPricesByPriceKind()
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;
	
	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",				ParentCompany);
	DataStructure.Insert("PriceKind",			Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	
	For Each TSRow In SalesTargetTable Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.Products) Then
			Continue;
		EndIf;
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products",		TSRow.Products);
		TabularSectionRow.Insert("Characteristic",	TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		TabularSectionRow.Insert("Price",			TSRow.Price);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
	
	DriveServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
	For Each TSRow In DocumentTabularSection Do
	
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",		TSRow.Products);
		SearchStructure.Insert("Characteristic",		TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit",	TSRow.MeasurementUnit);
		
		SearchResult = SalesTargetTable.FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RecalculateTabularSectionPricesByCurrency(PreviousCurrency)
	
	RatesStructure = GetExchangeRate(Object.Company, PreviousCurrency, Object.DocumentCurrency, Object.Date);
	ExchangeRateMethod = GetExchangeRateMethod(Object.Company);
	
	For Each TabularSectionRow In SalesTargetTable Do
		
		If SalesGoalSettingAttributes.SpecifyQuantity Then
			TabularSectionRow.Price = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.Price,
				GetExchangeRateMethod(Object.Company),
				RatesStructure.InitRate,
				RatesStructure.Rate,
				RatesStructure.RepetitionBeg,
				RatesStructure.Repetition,
				PricesPrecision);
			
			CalculateRowAmount(TabularSectionRow, Periods);
			
		Else
			
			For Index = 0 To Periods.Count() - 1 Do
				
				TabularSectionRow["ColumnAmount_" + Format(Index, "NZ=0; NG=0")] = DriveServer.RecalculateFromCurrencyToCurrency(
					TabularSectionRow["ColumnAmount_" + Format(Index, "NZ=0; NG=0")],
					GetExchangeRateMethod(Object.Company),
					RatesStructure.InitRate,
					RatesStructure.Rate,
					RatesStructure.RepetitionBeg,
					RatesStructure.Repetition,
					PricesPrecision);
				
			EndDo;
			
		EndIf;
		
		CalculateRowTotals(TabularSectionRow, Periods);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region InteractiveActions

&AtClient
Procedure AskChangeSalesGoalSetting(Result, AdditionalParameters) Export
	
	If Result.Property("Value") And Result.Value = DialogReturnCode.Yes Then
		OnChangeSalesGoalSettingAtServer();
		FormManagement();
	Else
		Object.SalesGoalSetting = AttributesStartValues.SalesGoalSetting;
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodOnChangeAtClient()
	
	SalesTargetingClientServer.SetStartEndOfTargetPeriod(
		SalesGoalSettingAttributes.Periodicity,
		Object.PeriodStartDate,
		Object.PeriodEndDate);
	
	If Object.PeriodStartDate <> AttributesStartValues.PeriodStartDate
		Or Object.PeriodEndDate <> AttributesStartValues.PeriodEndDate Then
		
		If SalesTargetTable.Count() > 0
			And (Object.PeriodStartDate > AttributesStartValues.PeriodStartDate
				Or Object.PeriodEndDate < AttributesStartValues.PeriodEndDate) Then
			
			NotifyDescription = New NotifyDescription("AskChangePeriod", ThisObject);
			QuestionText = NStr("en = 'Sales target contains filled data.
				|On change sales goal setting, the columns of Inventory table will be changed.
				|
				|Continue?'; 
				|ru = 'План продаж содержит заполненные данные.
				|При изменении настройки плана продаж колонки ТМЦ будут изменены.
				|
				|Продолжить?';
				|pl = 'Plan sprzedaży zawiera wypełnione dane.
				|W przypadku zmiany ustawień planu sprzedaży, kolumny sekcji tabelarycznej Zapasy zostanie zmieniona.
				|
				|Kontynuować?';
				|es_ES = 'El objetivo de ventas contiene datos completos. 
				|En la configuración de los objetivos de ventas, se modificarán las columnas de la tabla Inventario..
				|
				|¿Continuar?';
				|es_CO = 'El objetivo de ventas contiene datos completos. 
				|En la configuración de los objetivos de ventas, se modificarán las columnas de la tabla Inventario..
				|
				|¿Continuar?';
				|tr = 'Satış hedefi doldurulmuş veriler içeriyor. 
				| Satış hedefini değiştirme ayarlarında Stok tablosunun sütunları değiştirilecek. 
				|
				| Devam edilsin mi?';
				|it = 'I target di vendita contengono dati compilati.
				|Durante la modifica delle impostazioni degli obiettivi di vendita, le colonne della tabella inventario saranno modificate.
				|
				|Continuare?';
				|de = 'Das Umsatzziel enthält gefüllte Daten.
				|Bei der Einstellung des Verkaufsziels werden die Spalten der Tabelle Bestand geändert.
				|
				|Fortsetzen?'");
			
			QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
			QuestionParameters.Title = NStr("en = 'Period changing'; ru = 'Изменение периода';pl = 'Zmiana okresu';es_ES = 'Cambiar el período';es_CO = 'Cambiar el período';tr = 'Dönem değiştirme';it = 'Modifica periodo';de = 'Periodenwechsel'");
			QuestionParameters.DoNotAskAgain = False;
			StandardSubsystemsClient.ShowQuestionToUser(
				NotifyDescription,
				QuestionText,
				QuestionDialogMode.YesNo,
				QuestionParameters);
			
		Else
					
			OnChangePeriodAtServer();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AskChangePeriod(Result, AdditionalParameters) Export
	
	If Result.Property("Value") And Result.Value = DialogReturnCode.Yes Then
		OnChangePeriodAtServer();
	Else
		Object.PeriodStartDate = AttributesStartValues.PeriodStartDate;
		Object.PeriodEndDate = AttributesStartValues.PeriodEndDate;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetPeriodEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		Object.PeriodStartDate = Result.StartDate;
		Object.PeriodEndDate = Result.EndDate;
	EndIf;
	PeriodOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure OpenPricesAndCurrencyFormEnd(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure") 
		AND Result.WereMadeChanges Then
		
		Modified = True;
		LockFormDataForEdit();
		
		FillPropertyValues(Object, Result, "PriceKind, DocumentCurrency, ExchangeRate, Multiplicity");
		GenerateLabelPricesAndCurrency(ThisObject);
		
		If SalesGoalSettingAttributes.SpecifyQuantity
			And Result.RefillPrices Then
			
			RefillTabularSectionPricesByPriceKind();
			CalculateRowsAmount(ThisObject);
			CalculateRowsTotals(ThisObject);
			
		EndIf;
		
		If Not Result.RefillPrices
			AND Result.RecalculatePrices Then
			
			RecalculateTabularSectionPricesByCurrency(Result.PrevCurrencyOfDocument);
			RecalculateSubtotal(ThisObject);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenFillingSettings(SchemaName, Title = "")
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	StartFilter = New Structure;
	StartFilter.Insert("Company", Object.Company);
	StartFilter.Insert("StructuralUnit", Object.StructuralUnit);
	StartFilter.Insert("SalesGoalSetting", Object.SalesGoalSetting);
	
	FormParameters = New Structure;
	FormParameters.Insert("OwnerUUID",				UUID);
	FormParameters.Insert("SchemaName",				SchemaName);
	FormParameters.Insert("Title",					Title);
	FormParameters.Insert("Dimensions",				SalesGoalSettingAttributes.Dimensions);
	FormParameters.Insert("Periodicity",			SalesGoalSettingAttributes.Periodicity);
	FormParameters.Insert("PeriodStartDate",		Object.PeriodStartDate);
	FormParameters.Insert("PeriodsQuantity",		Periods.Count());
	FormParameters.Insert("CurrentDocument",		Object.Ref);
	FormParameters.Insert("DocumentCurrency",		Object.DocumentCurrency);
	FormParameters.Insert("StartFilter",			StartFilter);	
	FormParameters.Insert("PresentationCurrency",	GetPresentationCurrency(Object.Company));
	
	NotifyDescription = New NotifyDescription("OpenFillingSettingsEnd", ThisObject);
	
	OpenForm("Document.SalesTarget.Form.FillingSettings", FormParameters, ThisObject,,,, NotifyDescription);
	
EndProcedure

&AtClient
Procedure OpenFillingSettingsEnd(Result, AdditionalParameters) Export
	
	If Result <> Undefined And TypeOf(Result) = Type("Structure") Then
		
		FillSalesTarget(Result);
		Modified = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	ArrayPeriods = New Array;
	
	For Index = 0 To Periods.Count() - 1 Do
		
		ArrayPeriods.Add(Periods.Get(Index).ColumnTitle);
		
	EndDo;
	
	DataLoadSettings.Insert("TabularSectionFullName",		"SalesTarget.Inventory");
	DataLoadSettings.Insert("Title",						NStr("en = 'Import inventory from file'; ru = 'Загрузка запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	DataLoadSettings.Insert("SalesGoalSettingAttributes",	SalesGoalSettingAttributes);
	DataLoadSettings.Insert("Periods",						ArrayPeriods);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		RecalculateSubtotal(ThisObject);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	For Each TableRow In ImportResult.DataMatchingTable Do
		
		If TableRow._ImportToApplicationPossible Then
			NewRow = SalesTargetTable.Add();
			FillPropertyValues(NewRow, TableRow);
			CalculateRowTotals(NewRow, Periods);
		EndIf;
		
	EndDo;
	
	FillLineNumbers(ThisObject);
	CalculateRowsQuantity(ThisObject);
	RecalculateSubtotal(ThisObject);
	
EndProcedure

// End StandardSubsystems.DataImportFromExternalSources

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

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.SalesTargetTablePrice);
	
	Return Fields;
	
EndFunction

#EndRegion

&AtServerNoContext
Function GetPresentationCurrency(Company)
	
	Return DriveServer.GetPresentationCurrency(Company);
	
EndFunction

#EndRegion