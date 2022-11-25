
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ObjectData = Catalogs.FinancialReportsItems.FormOnCreateAtServer(ThisObject);
	ValuesSources.Load(ObjectData.ValuesSources);
	
	ItemsTrees = FormDataToValue(Parameters.ReportItems, Type("ValueTree"));
	ReportItemsAddress = PutToTempStorage(ItemsTrees, UUID);
	
	Title = Parameters.ItemType;
	
	If DimensionType = Enums.FinancialReportDimensionTypes.AccountingRegisterDimension Then
		Items.DimensionName.ChoiceList.Clear();
		Items.DimensionName.ChoiceList.Add("Company", NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
		If Catalogs.BusinessUnits.AccountingByBusinessUnits() Then
			Items.DimensionName.ChoiceList.Add("BusinessUnit", NStr("en = 'Business unit'; ru = 'Подразделение';pl = 'Jednostka biznesowa';es_ES = 'Unidad empresarial';es_CO = 'Unidad de negocio';tr = 'Departman';it = 'Unità aziendale';de = 'Abteilung'"));
		EndIf;
		If Catalogs.LinesOfBusiness.AccountingByLinesOfBusiness() Then
			Items.DimensionName.ChoiceList.Add("LineOfBusiness", NStr("en = 'Line of business'; ru = 'Направление деятельности';pl = 'Rodzaj działalności';es_ES = 'Dirección de negocio';es_CO = 'Dirección de negocio';tr = 'İş kolu';it = 'Linea di business';de = 'Geschäftsbereich'"));
		EndIf;
		Items.DimensionName.TextEdit = False;
	ElsIf DimensionType = Enums.FinancialReportDimensionTypes.AnalyticalDimension Then
		DimensionName = "<AnalyticalDimensionType>";
		Items.DimensionName.Visible = False;
		Items.AnalyticalDimensionType.Visible = True;
		Items.AnalyticalDimensionType.TypeRestriction = FinancialReportingServer.TypeDescriptionByValue(AnalyticalDimensionType);
	EndIf;
	
	FormAdditionalMode = Parameters.FormAdditionalMode;
	
	FormManagement();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Catalogs.FinancialReportsItems.FormBeforeWriteAtServer(ThisObject, CurrentObject, Cancel);
	ObjectData = GetFromTempStorage(ItemAddressInTempStorage);
	ObjectData.ValuesSources = ValuesSources.Unload();
	PutToTempStorage(ObjectData, ItemAddressInTempStorage);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If ValueIsFilled(ItemAddressInTempStorage) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(
		Item.EditText, 
		ThisObject, 
		"Object.Comment");
	
EndProcedure

&AtClient
Procedure DimensionNameOnChange(Item)
	
	If Not ValueIsFilled(DimensionName) Then
		Return;
	EndIf;
	
	Object.DescriptionForPrinting = Items.DimensionName.ChoiceList.FindByValue(DimensionName).Presentation;
	If DimensionType = PredefinedValue("Enum.FinancialReportDimensionTypes.AccountingRegisterDimension") Then
		ConfigureFilterField();
	EndIf;
	
EndProcedure

&AtClient
Procedure AnalyticalDimensionTypeOnChange(Item)
	
	AnalyticalDimensionTypeOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure SelectedValuesSourcesOnChange(Item)
	
	If SelectedValuesSources Then
		FillSourcesByDefault();
	Else
		FormManagement();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FinishEditing(Command)
	
	FinancialReportingClient.FinishEditingReportItem(ThisObject);
	
EndProcedure

&AtClient
Procedure SelectSources(Command)
	
	SourcesSelectionParameters = New Structure("ItemAddressInTempStorage, ReportItemsAddress, ValuesSources", 
		ItemAddressInTempStorage, ReportItemsAddress, ValuesSources);
	
	Notification = New NotifyDescription("ValuesSourcesSelection", ThisObject);
	OpenForm("Catalog.FinancialReportsItems.Form.ValuesSources", SourcesSelectionParameters
		, , , , , Notification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FormManagement()
	
	Items.GroupSources.Visible = (FormAdditionalMode <> Enums.ReportItemsAdditionalModes.ReportType);
	
	Items.SelectSources.Enabled = SelectedValuesSources;
	If Items.SelectSources.Enabled And ValuesSources.Count() Then
		SelectSourcesTitle = NStr("en = 'Modify sources (%1)'; ru = 'Изменить источники (%1)';pl = 'Modyfikuj źródła (%1)';es_ES = 'Modificar las fuentes (%1)';es_CO = 'Modificar las fuentes (%1)';tr = 'Kaynakları düzenle (%1)';it = 'Modificare fonti (%1)';de = 'Quellen ändern (%1)'");
		SelectSourcesTitle = StringFunctionsClientServer.SubstituteParametersToString(SelectSourcesTitle, ValuesSources.Count());
	Else
		SelectSourcesTitle = NStr("en = 'Not specified'; ru = 'Не указан';pl = 'Nie określono metody płatności';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmemiş';it = 'Non specificato';de = 'Keine Angabe'");
	EndIf;
	Items.SelectSources.Title = SelectSourcesTitle;
	
EndProcedure

&AtServer
Procedure AnalyticalDimensionTypeOnChangeAtServer()
	
	Object.DescriptionForPrinting = Common.ObjectAttributeValue(AnalyticalDimensionType, "Description");
	ConfigureFilterField();
	
EndProcedure

&AtServer
Procedure ConfigureFilterField()
	
	Catalogs.FinancialReportsItems.SetFilterSettings(ThisObject, ThisObject.Composer, Object.ItemType, Composer.Settings);
	
EndProcedure

&AtClient
Procedure ValuesSourcesSelection(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ValuesSources.Clear();
	CommonClientServer.SupplementTableFromArray(ValuesSources, Result, "Source");
	
	FormManagement();
	
EndProcedure

&AtServer
Procedure FillSourcesByDefault()
	Var Cache;
	
	CalculatedValuesSources = FinancialReportingServer.DefaultValuesSources(Cache, ReportItemsAddress, ItemAddressInTempStorage);
	ValuesSources.Load(CalculatedValuesSources);
	FormManagement();
	
EndProcedure

#EndRegion
