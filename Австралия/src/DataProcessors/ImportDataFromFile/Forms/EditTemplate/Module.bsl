#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SetDataAppearance();
	
	ImportParameters = Parameters.ImportParameters;

	MappingObjectName = Parameters.MappingObjectName;
	If Parameters.Property("ColumnsInformation") Then
		ColumnsList.Load(Parameters.ColumnsInformation.Unload());
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	ColumnPosition = 0;
	For Each TableRow In ColumnsList Do
		If TableRow.Visible Then
			ColumnPosition = ColumnPosition + 1;
			TableRow.Position = ColumnPosition;
		Else
			TableRow.Position = -1;
		EndIf;
	EndDo;
	Close(ColumnsList);
EndProcedure

&AtClient
Procedure ClearSettings(Command)
	Notification = New NotifyDescription("ClearSettingsCompletion", ThisObject, MappingObjectName);
	ShowQueryBox(Notification, NStr("ru = 'Установить настройки колонок в первоначальное состояние?'; en = 'Set the column settings back to their original state?'; pl = 'Przywrócić pierwotne ustawienia kolumn?';es_ES = '¿Volver a establecer las configuraciones de la columna para su estado original?';es_CO = '¿Volver a establecer las configuraciones de la columna para su estado original?';tr = 'Sütun ayarlarını fabrika ayarlarına çevirmek mi istiyorsunuz?';it = 'Impostare le impostazioni di colonna al loro stato originale?';de = 'Setzen Sie die Spalteneinstellungen auf ihren ursprünglichen Zustand zurück?'"), QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure SelectAll(Command)
	For each TableRow In ColumnsList Do 
		TableRow.Visible = True;
	EndDo;
EndProcedure

&AtClient
Procedure ClearAll(Command)
	For each TableRow In ColumnsList Do
		If Not TableRow.Required Then
			TableRow.Visible = False;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region ColumnsListHandlers

&AtClient
Procedure ColumnsListOnActivateRow(Item)
	If Item.CurrentData <> Undefined Then 
		ColumnDetails = Item.CurrentData.Comment;
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetDataAppearance()

	ConditionalAppearance.Items.Clear();
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("ColumnsListDescription");
	AppearanceField.Use = True;
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ColumnsList.Required"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal; 
	FilterItem.RightValue =True;
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,, True));
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("ColumnsListVisibility");
	AppearanceField.Use = True;
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ColumnsList.Required"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal; 
	FilterItem.RightValue =True;
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("ReadOnly", True);
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("ColumnsListSynonym");
	AppearanceField.Use = True;
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("ColumnsList.Synonym");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("ru = 'Стандартное наименование'; en = 'Standard name'; pl = 'Nazwa standardowa';es_ES = 'Nombre estándar';es_CO = 'Nombre estándar';tr = 'Standart isim';it = 'Denomiazione standard';de = 'Standardname'"));
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

&AtClient
Procedure ClearSettingsCompletion(QuestionResult, MappingObjectName) Export
	If QuestionResult = DialogReturnCode.Yes Then
		ResetColumnsSettings(MappingObjectName);
	EndIf;
EndProcedure

&AtServer
Procedure ResetColumnsSettings(MappingObjectName)
	
	Common.CommonSettingsStorageSave("ImportDataFromFile", MappingObjectName, Undefined,, UserName());
	
	ColumnsListTable = ColumnsList.Unload();
	ColumnsListTable.Clear();
	DataProcessors.ImportDataFromFile.DetermineColumnsInformation(ImportParameters, ColumnsListTable);
	ValueToFormAttribute(ColumnsListTable, "ColumnsList");
	
EndProcedure

#EndRegion
