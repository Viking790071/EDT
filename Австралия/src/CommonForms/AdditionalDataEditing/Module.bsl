
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not AccessRight("Update", Metadata.InformationRegisters.AdditionalInfo) Then
		Items.FormWrite.Visible = False;
		Items.FormWriteAndClose.Visible = False;
	EndIf;
	
	If Not AccessRight("Update", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
		Items.ChangeAdditionalDataContent.Visible = False;
	EndIf;
	
	ObjectRef = Parameters.Ref;
	
	// Getting the list of available property sets.
	PropertySets = PropertyManagerInternal.GetObjectPropertySets(Parameters.Ref);
	For each Row In PropertySets Do
		AvailablePropertySets.Add(Row.Set);
	EndDo;
	
	// Filling the property value table.
	FillPropertiesValuesTable(True);
	
	If CommonClientServer.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "FormWriteAndClose", "Picture", PictureLib.WriteAndClose);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseCompletion", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalDataAndAttributeSets" Then
		
		If AvailablePropertySets.FindByValue(Source) <> Undefined Then
			FillPropertiesValuesTable(False);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region PropertiesValuesTableFormTableItemsEventsHandlers

&AtClient
Procedure PropertiesValuesTableOnChange(Item)
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure PropertiesValuesTableBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesValuesTableBeforeDelete(Item, Cancel)
	
	If Item.CurrentData.PictureNumber = -1 Then
		Cancel = True;
		Item.CurrentData.Value = Item.CurrentData.ValueType.AdjustValue(Undefined);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertiesValuesTableOnStartEdit(Item, NewRow, Clone)
	
	Item.ChildItems.PropertyValueTableValue.TypeRestriction
		= Item.CurrentData.ValueType;
	
EndProcedure

&AtClient
Procedure PropertiesValuesTableBeforeChangeStart(Item, Cancel)
	If Items.PropertyValueTable.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Row = Items.PropertyValueTable.CurrentData;
	
	ChoiceParametersArray = New Array;
	If Row.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
		Or Row.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
		ChoiceParametersArray.Add(New ChoiceParameter("Filter.Owner",
			?(ValueIsFilled(Row.AdditionalValuesOwner),
				Row.AdditionalValuesOwner, Row.Property)));
	EndIf;
	Items.PropertyValueTableValue.ChoiceParameters = New FixedArray(ChoiceParametersArray);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Write(Command)
	
	WritePropertiesValues();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure ChangeAdditionalDataContent(Command)
	
	If AvailablePropertySets.Count() = 0
	 OR NOT ValueIsFilled(AvailablePropertySets[0].Value) Then
		
		ShowMessageBox(,
			NStr("ru = 'Не удалось получить наборы дополнительных сведений объекта.
			           |
			           |Возможно у объекта не заполнены необходимые реквизиты.'; 
			           |en = 'Cannot get sets of additional object information.
			           |
			           |Required object attributes might not be filled in.'; 
			           |pl = 'Nie udało się uzyskać dodatkowych zestawów informacji o obiekcie.
			           |
			           |Być może wymagane atrybuty nie zostały wypełnione dla dokumentu.';
			           |es_ES = 'Fallado a obtener los conjuntos de la información adicional del objeto.
			           |
			           |Probablemente los atributos necesarios no se han rellenado para el documento.';
			           |es_CO = 'Fallado a obtener los conjuntos de la información adicional del objeto.
			           |
			           |Probablemente los atributos necesarios no se han rellenado para el documento.';
			           |tr = 'Nesnenin ek bilgi kümeleri alınamadı.
			           |
			           |Belge için gereken özellikler doldurulmamış olabilir.';
			           |it = 'Impossibile ottenere set di informazioni dell''oggetto aggiuntivo.
			           |
			           |Gli attributi richiesti dell''oggetto potrebbero non essere compilati.';
			           |de = 'Fehler beim Abrufen der zusätzlichen Informationssätze des Objekts.
			           |
			           |Möglicherweise wurden die erforderlichen Attribute für das Dokument nicht ausgefüllt.'"));
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ShowAdditionalInfo");
		
		OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm", FormParameters);
		
		MigrationParameters = New Structure;
		MigrationParameters.Insert("Set", AvailablePropertySets[0].Value);
		MigrationParameters.Insert("Property", Undefined);
		MigrationParameters.Insert("IsAdditionalInfo", True);
		
		If Items.PropertyValueTable.CurrentData <> Undefined Then
			MigrationParameters.Insert("Set", Items.PropertyValueTable.CurrentData.Set);
			MigrationParameters.Insert("Property", Items.PropertyValueTable.CurrentData.Property);
		EndIf;
		
		Notify("Go_AdditionalDataAndAttributeSets", MigrationParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure WriteAndCloseCompletion(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WritePropertiesValues();
	Modified = False;
	Close();
	
EndProcedure

&AtServer
Procedure FillPropertiesValuesTable(FromOnCreateHandler)
	
	// Filling the tree with property values.
	If FromOnCreateHandler Then
		PropertiesValues = ReadPropertiesValuesFromInfoRegister(Parameters.Ref);
	Else
		PropertiesValues = GetCurrentPropertiesValues();
		PropertyValueTable.Clear();
	EndIf;
	
	TableToCheck = "InformationRegister.AdditionalInfo";
	AccessValue = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo");
	
	Table = PropertyManagerInternal.PropertiesValues(
		PropertiesValues, AvailablePropertySets, True);
	
	ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
	CheckRights = Not Users.IsFullUser() AND Common.SubsystemExists("StandardSubsystems.AccessManagement");
	If CheckRights Then
		PropertiesToCheck = Table.UnloadColumn("Property");
		AllowedProperties = ModuleAccessManagementInternal.AllowedDynamicListValues(
			TableToCheck,
			AccessValue,
			PropertiesToCheck);
	EndIf;
	
	For Each Row In Table Do
		Editable = True;
		If CheckRights Then
			// Check for reading the property.
			If AllowedProperties.Find(Row.Property) = Undefined Then
				Continue;
			EndIf;
			
			// Check for writing the property.
			BeginTransaction();
			Try
				Set = InformationRegisters.AdditionalInfo.CreateRecordSet();
				Set.Filter.Object.Set(Parameters.Ref);
				Set.Filter.Property.Set(Row.Property);
				
				Record = Set.Add();
				Record.Property = Row.Property;
				Record.Object = Parameters.Ref;
				Set.DataExchange.Load = True;
				Set.Write(True);
				
				RollbackTransaction();
			Except
				ErrorInformation = ErrorInfo();
				DetailErrorDescription(ErrorInformation);
				RollbackTransaction();
				Editable = False;
			EndTry;
		EndIf;
		
		NewRow = PropertyValueTable.Add();
		FillPropertyValues(NewRow, Row);
		
		NewRow.PictureNumber = ?(Row.Deleted, 0, -1);
		NewRow.Editable = Editable;
		
		If Row.Value = Undefined
			AND Common.TypeDetailsContainsType(Row.ValueType, Type("Boolean")) Then
			NewRow.Value = False;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure WritePropertiesValues()
	
	// Writing property values in the information register.
	PropertiesValues = New Array;
	
	For Each Row In PropertyValueTable Do
		Value = New Structure("Property, Value", Row.Property, Row.Value);
		PropertiesValues.Add(Value);
	EndDo;
	
	If PropertiesValues.Count() > 0 Then
		WritePropertySetInRegister(ObjectRef, PropertiesValues);
	EndIf;
	
	Modified = False;
	
EndProcedure

&AtServerNoContext
Procedure WritePropertySetInRegister(Val Ref, Val PropertiesValues)
	
	SetPrivilegedMode(True);
	
	Set = InformationRegisters.AdditionalInfo.CreateRecordSet();
	Set.Filter.Object.Set(Ref);
	Set.Read();
	CurrentValues = Set.Unload();
	For Each Row In PropertiesValues Do
		Record = CurrentValues.Find(Row.Property, "Property");
		If Record = Undefined Then
			Record = CurrentValues.Add();
			Record.Property = Row.Property;
			Record.Value = Row.Value;
			Record.Object   = Ref;
		EndIf;
		Record.Value = Row.Value;
		
		If Not ValueIsFilled(Record.Value)
			Or Record.Value = False Then
			CurrentValues.Delete(Record);
		EndIf;
	EndDo;
	Set.Load(CurrentValues);
	Set.Write();
	
EndProcedure

&AtServerNoContext
Function ReadPropertiesValuesFromInfoRegister(Ref)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalInfo.Property,
	|	AdditionalInfo.Value
	|FROM
	|	InformationRegister.AdditionalInfo AS AdditionalInfo
	|WHERE
	|	AdditionalInfo.Object = &Object";
	Query.SetParameter("Object", Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
Function GetCurrentPropertiesValues()
	
	PropertiesValues = New ValueTable;
	PropertiesValues.Columns.Add("Property");
	PropertiesValues.Columns.Add("Value");
	
	For each Row In PropertyValueTable Do
		
		If ValueIsFilled(Row.Value) AND (Row.Value <> False) Then
			NewRow = PropertiesValues.Add();
			NewRow.Property = Row.Property;
			NewRow.Value = Row.Value;
		EndIf;
	EndDo;
	
	Return PropertiesValues;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PropertyValueTableValue.Name);
	
	// Date format - time.
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PropertyValueTable.ValueType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New TypeDescription("Date",,, New DateQualifiers(DateFractions.Time));
	Item.Appearance.SetParameterValue("Format", "DLF=T");
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PropertyValueTableValue.Name);
	
	// Date format - date.
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PropertyValueTable.ValueType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New TypeDescription("Date",,, New DateQualifiers(DateFractions.Date));
	Item.Appearance.SetParameterValue("Format", "DLF=D");
	
	//
	Item = ConditionalAppearance.Items.Add();
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PropertyValueTableValue.Name);
	
	// Field availability if you have no change rights.
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PropertyValueTable.Editable");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	Item.Appearance.SetParameterValue("ReadOnly", True);
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

#EndRegion
