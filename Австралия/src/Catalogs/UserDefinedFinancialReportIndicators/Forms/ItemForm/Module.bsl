
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If ValueIsFilled(Object.Ref) Then
		
		Set = InformationRegisters.UserDefinedFinancialReportIndicatorsValues.CreateRecordSet();
		Set.Filter.Indicator.Set(Object.Ref);
		Set.Read();
		IndicatorValues = Set.Unload();
		ValueToFormAttribute(IndicatorValues, "RecordSet");
		
	EndIf;
	
	RefreshFormTitle();
	DescriptionCache = Object.Description;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	RowNumber = 1;
	
	For Each RecordSetRow In RecordSet Do
		
		If Not ValueIsFilled(RecordSetRow.Period) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Starting date for the value in the line #%1 is not specified.'; ru = 'Начальная дата для значения в строке №%1 не указана.';pl = 'Data początku dla wartości w wierszu nr %1 nie jest wybrana.';es_ES = 'No se especifica la fecha de inicio del valor en la %1 línea #.';es_CO = 'No se especifica la fecha de inicio del valor en la %1 línea #.';tr = '#%1 satırındaki değer için başlangıç tarihi belirtilmemiş.';it = 'La data di inizio per il valore nella linea #%1 non è specificato.';de = 'Das Startdatum für den Wert in der Zeile Nr %1 ist nicht angegeben.'"),
				RowNumber);
			CommonClientServer.MessageToUser(
				MessageText,
				Object.Ref,
				CommonClientServer.PathToTabularSection("RecordSet", RowNumber, "Period"),
				,
				Cancel);
		EndIf;
		If Not ValueIsFilled(RecordSetRow.Author) Then
			RecordSetRow.Author = Users.CurrentUser();
		EndIf;
		RowNumber = RowNumber + 1;
	EndDo;
	
	RefreshFormTitle();

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	Set = InformationRegisters.UserDefinedFinancialReportIndicatorsValues.CreateRecordSet();
	Set.Filter.Indicator.Set(Object.Ref);
	IndicatorValues = FormAttributeToValue("RecordSet");
	IndicatorValues.FillValues(Object.Ref, "Indicator");
	Set.Load(IndicatorValues);
	Set.Write();

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_UserDefinedFinancialReportIndicator", , Object.Ref);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	If DescriptionCache = Object.DescriptionForPrinting Or IsBlankString(Object.DescriptionForPrinting) Then
		Object.DescriptionForPrinting = Object.Description;
	EndIf;
	DescriptionCache = Object.Description;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(
		Item.EditText, 
		ThisObject, 
		"Object.Comment");
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecordSet

&AtClient
Procedure RecordSetOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		RecordSetRow = Items.RecordSet.CurrentData;
		RecordSetRow.Period = CommonClient.SessionDate();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RecordSetCompany.Name);
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RecordSet.Company");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
	Item.Appearance.SetParameterValue("Text", NStr("en = '<Use for all>'; ru = '<Использовать для всех>';pl = '<Użyj dla wszystkich>';es_ES = '<Aplicado para todos>';es_CO = '<Aplicado para todos>';tr = '<Tümü için kullan>';it = '<Utilizza per tutti>';de = '<Für alle verwenden>'"));
	
	If Catalogs.BusinessUnits.AccountingByBusinessUnits() Then
	
		Item = ConditionalAppearance.Items.Add();
		ItemField = Item.Fields.Items.Add();
		ItemField.Field = New DataCompositionField(Items.RecordSetBusinessUnit.Name);
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("RecordSet.BusinessUnit");
		ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
		Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
		Item.Appearance.SetParameterValue("Text", NStr("en = '<Use for all>'; ru = '<Использовать для всех>';pl = '<Użyj dla wszystkich>';es_ES = '<Aplicado para todos>';es_CO = '<Aplicado para todos>';tr = '<Tümü için kullan>';it = '<Utilizza per tutti>';de = '<Für alle verwenden>'"));
		
	Else
		
		Items.RecordSetBusinessUnit.Visible = False;
		
	EndIf;

EndProcedure

&AtServer
Procedure RefreshFormTitle()
	
	TypePresentation = NStr("en = 'User-defined indicator'; ru = 'Пользовательский индикатор';pl = 'Wskaźnik zdefiniowany przez użytkownika';es_ES = 'Indicador definido por el usuario';es_CO = 'Indicador definido por el usuario';tr = 'Kullanıcı tanımlı gösterge';it = 'Indicatore definito dall''utente';de = 'Benutzerdefiniertes Kennzeichen'");
	If Not ValueIsFilled(Object.Ref) Then
		Title = TypePresentation + " (" + NStr("en = 'new'; ru = 'новый';pl = 'nowy';es_ES = 'nuevo';es_CO = 'nuevo';tr = 'yeni';it = 'nuovo';de = 'neu'") + ")";
	Else
		Title = Object.DescriptionForPrinting + " (" + TypePresentation + ")";
	EndIf;
	
EndProcedure

#EndRegion
