#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Products", Products);
	
	If ValueIsFilled(Products) Then
		
		TitleTemplate = NStr("en = 'Variants generator for %1'; ru = 'Генератор вариантов для %1';pl = 'Generator wariantów dla %1';es_ES = 'Generador de variantes para %1';es_CO = 'Generador de variantes para %1';tr = '%1 için varyant oluşturucu';it = 'Generatore varianti per %1';de = 'Varianten-Generator für %1'");
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			TitleTemplate,
			Products);
		
		If DriveServer.UseVariantsGenerator(Products) Then
			
			CreateListTable();
			FillListTable();
			
		Else
			
			Items.DecorationFornUnavailable.Visible = True;
			ThisObject.Enabled = False;
			
		EndIf;
		
	Else
		
		Items.DecorationFornUnavailable.Visible = True;
		ThisObject.Enabled = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnChange(Item)
	
	NameParts = StrSplit(Items.List.CurrentItem.Name, "_");
	SelectedRow = Items.List.CurrentRow;
	
	If NameParts.Count() = 2 Then
		
		ColumnName = NameParts[1];
		
		ListRow = List[SelectedRow];
		
		If Not ListRow[ColumnName] Then
			
			// Check if variant had already been created
			
			FilterColumn = New Structure;
			FilterColumn.Insert("Name", ColumnName);
			ColumnValues = ColumnsMap.FindRows(FilterColumn);
			
			FilterRow = New Structure;
			FilterRow.Insert("Name", ListRow.RowName);
			RowValues = RowsMap.FindRows(FilterRow);
			
			If ColumnValues.Count() And RowValues.Count() Then
				
				ColumnValue = ColumnValues[0].Value;
				RowValue = RowValues[0].Value;
				
				Filter = New Structure;
				Filter.Insert("ColumnValue", ColumnValue);
				Filter.Insert("RowValue", RowValue);
				CreatedVariantsRows = CreatedVariants.FindRows(Filter);
				
				If CreatedVariantsRows.Count() Then
					
					ListRow[ColumnName] = True;
					ShowUserNotification(NStr("en = 'This variant already exists'; ru = 'Данный вариант уже существует';pl = 'Taki wariant już istnieje';es_ES = 'Esta variante ya existe';es_CO = 'Esta variante ya existe';tr = 'Bu varyant zaten var';it = 'Questa variante già esiste';de = 'Diese Variante existiert bereits'"));
					
				EndIf;
				
			EndIf;
			
		Else
			
			ThisObject.Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Generate(Command)
	
	GenerateVariants();
	
EndProcedure

&AtClient
Procedure GenerateBarcodes(Command)
	
	If ThisObject.Modified Then
		
		Notification = New NotifyDescription("AfterUnsavedVariantsQuestion", ThisObject, Parameters);
		ShowQueryBox(
			Notification,
			NStr("en = 'You have to generate checked variants before barcodes generation.
						|Generate varians and continue barcodes generation?'; 
						|ru = 'Вы должны создать проверенные варианты перед генерацией штрихкодов.
						|Сгенерировать варианты и продолжить генерировать штрихкоды?';
						|pl = 'Musisz wygenerować sprawdzone warianty przed generacją kodów kreskowych.
						|Wygenerować warianty i kontynuować generację kodów kreskowych?';
						|es_ES = 'Las variantes verificadas deben generarse antes de la generación de los códigos de barras.
						| ¿Generar variantes y continuar la generación de códigos de barras?';
						|es_CO = 'Las variantes verificadas deben generarse antes de la generación de los códigos de barras.
						| ¿Generar variantes y continuar la generación de códigos de barras?';
						|tr = 'Barkod üretmeden önce kontrol edilmiş varyantlar üretmelisiniz. 
						| Varyant oluşturup barkod üretimine devam edilsin mi?';
						|it = 'Dovete generare varianti controllate prima della generazione dei codici a barre.
						|Generare varianti e continuare con la generazione codici a barre?';
						|de = 'Sie müssen vor der Barcode-Generierung geprüfte Varianten generieren.
						|Varianten generieren und Barcode-Generierung fortsetzen?'"),
			QuestionDialogMode.OKCancel);
		
	Else
		
		ClearMessages();
		GenerateBarcodesAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListSelectAll(Command)
	
	For Each ListRow In List Do
		
		For Each ListColumn In ColumnsMap Do
			
			ListRow[ListColumn.Name] = True;
			
		EndDo;
		
	EndDo;
	
	ThisObject.Modified = True;
	
EndProcedure

&AtClient
Procedure ListClearAll(Command)
	
	For Each ListRow In List Do
		
		Filter = New Structure;
		Filter.Insert("Name", ListRow.RowName);
		
		RowValues = RowsMap.FindRows(Filter);
		
		If RowValues.Count() Then
			
			RowValue = RowValues[0].Value;
			
			For Each ListColumn In ColumnsMap Do
				
				ListRow[ListColumn.Name] = False;
				
				Filter = New Structure;
				Filter.Insert("ColumnValue", ListColumn.Value);
				Filter.Insert("RowValue", RowValue);
				CreatedVariantsRows = CreatedVariants.FindRows(Filter);
				
				If CreatedVariantsRows.Count() Then
					
					ListRow[ListColumn.Name] = True;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	ThisObject.Modified = False;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CreateListTable()
	
	ProductsCategory = Common.ObjectAttributeValue(Products, "ProductsCategory");
	
	SetOfCharacteristicProperties = Common.ObjectAttributeValue(ProductsCategory, "SetOfCharacteristicProperties");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributes.Property AS Property
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributes
	|WHERE
	|	AdditionalAttributes.Ref = &SetOfCharacteristicProperties
	|	AND NOT AdditionalAttributes.DeletionMark
	|
	|ORDER BY
	|	AdditionalAttributes.LineNumber";
	
	Query.SetParameter("SetOfCharacteristicProperties", SetOfCharacteristicProperties);
	
	AdditionalAttributes = Query.Execute().Unload();
	
	If AdditionalAttributes.Count() > 0 Then
		
		RowsCharacteristic = AdditionalAttributes[0].Property;
		
		Matrix = New ValueTable;
		
		QS = New StringQualifiers(150);
		Array = New Array;
		Array.Add(Type("String"));
		TypeDescriptionS = New TypeDescription(Array, , QS);
		
		Array = New Array;
		Array.Add(Type("Boolean"));
		TypeDescriptionB = New TypeDescription(Array);
		
		If AdditionalAttributes.Count() > 1 Then
			
			ColumnsCharacteristic = AdditionalAttributes[1].Property;
			
			Matrix.Columns.Add("RowName", TypeDescriptionS, RowsCharacteristic.Title + "/" + ColumnsCharacteristic.Title);
			
			Query = New Query;
			Query.Text = 
			"SELECT
			|	ObjectsPropertiesValues.Ref AS Value,
			|	ObjectsPropertiesValues.Description AS Description
			|FROM
			|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
			|WHERE
			|	NOT ObjectsPropertiesValues.IsFolder
			|	AND NOT ObjectsPropertiesValues.DeletionMark
			|	AND ObjectsPropertiesValues.Owner = &ColumnsCharacteristic
			|
			|ORDER BY
			|	ObjectsPropertiesValues.Description";
			
			Query.SetParameter("ColumnsCharacteristic", ColumnsCharacteristic);
			QueryResult = Query.Execute();
			SelectionDetailRecords = QueryResult.Select();
			
			Counter = 0;
			
			While SelectionDetailRecords.Next() Do
				
				ColumnMap = ColumnsMap.Add();
				ColumnMap.Name = "Column" + Format(Counter, "NZ=0; NG=0");
				ColumnMap.Value = SelectionDetailRecords.Value;
				
				Matrix.Columns.Add(ColumnMap.Name, TypeDescriptionB, SelectionDetailRecords.Description);
				
				Counter = Counter + 1;
				
			EndDo;
			
		Else
			
			Matrix.Columns.Add("RowName", TypeDescriptionS, RowsCharacteristic.Title);
			
			// Only 1 column
			ColumnMap = ColumnsMap.Add();
			ColumnMap.Name = "Column0";
			ColumnMap.Value = Undefined;
			
			Matrix.Columns.Add(ColumnMap.Name, TypeDescriptionB, NStr("en = 'Generate'; ru = 'Сформировать';pl = 'Wygeneruj';es_ES = 'Generar';es_CO = 'Generar';tr = 'Oluştur';it = 'Genera';de = 'Generieren'"));
			
		EndIf;
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ObjectsPropertiesValues.Ref AS Value,
		|	ObjectsPropertiesValues.Description AS Name
		|FROM
		|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
		|WHERE
		|	NOT ObjectsPropertiesValues.IsFolder
		|	AND NOT ObjectsPropertiesValues.DeletionMark
		|	AND ObjectsPropertiesValues.Owner = &RowsCharacteristic
		|
		|ORDER BY
		|	ObjectsPropertiesValues.Description";
		
		Query.SetParameter("RowsCharacteristic", RowsCharacteristic);
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			
			RowMap = RowsMap.Add();
			FillPropertyValues(RowMap, SelectionDetailRecords);
			
			MatrixRow = Matrix.Add();
			MatrixRow.RowName = RowMap.Name;
			
		EndDo;
		
		// Matrix into List
		
		NewAttributes = New Array;
		
		For Each Column In Matrix.Columns Do
			NewAttributes.Add(New FormAttribute(Column.Name, Column.ValueType, "List", Column.Title));
		EndDo;
		
		ChangeAttributes(NewAttributes);
		
		For Each Column In Matrix.Columns Do
			
			If Column.Name = "RowName" Then
				
				NewItem = Items.Add("List_" + Column.Name, Type("FormField"), Items.List);
				NewItem.Type = FormFieldType.InputField;
				NewItem.DataPath = "List." + Column.Name;
				NewItem.Width = 20;
				NewItem.ReadOnly = True;
				NewItem.BackColor = StyleColors.TableHeaderBackColor;
				NewItem.FixingInTable = FixingInTable.Left;
				
			Else
				
				NewItem = Items.Add("List_" + Column.Name, Type("FormField"), Items.List);
				NewItem.Type = FormFieldType.CheckBoxField;
				NewItem.DataPath = "List." + Column.Name;
				NewItem.ToolTip = NStr("en = 'Create variant'; ru = 'Создать вариант';pl = 'Utwórz wariant';es_ES = 'Crear la variante';es_CO = 'Crear la variante';tr = 'Varyant oluştur';it = 'Crea variante';de = 'Variante erstellen'");
				
			EndIf;
			
		EndDo;
		
		ValueToFormAttribute(Matrix, "List");
		
	EndIf;

EndProcedure

&AtServer
Procedure FillListTable()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProductsCharacteristics.Ref AS Characteristic,
		|	ProductsCharacteristics.Owner AS Products
		|INTO Variants
		|FROM
		|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
		|WHERE
		|	ProductsCharacteristics.Owner = &Products";
	
	DriveClientServer.AddDelimeter(Query.Text);
	
	If ValueIsFilled(ColumnsCharacteristic) Then
		
		Query.Text = Query.Text + "
		|SELECT
		|	Variants.Characteristic AS Characteristic,
		|	ColumnValue.Value AS ColumnValue,
		|	RowValue.Value AS RowValue
		|FROM
		|	Variants AS Variants
		|		INNER JOIN Catalog.ProductsCharacteristics.AdditionalAttributes AS ColumnValue
		|		ON Variants.Characteristic = ColumnValue.Ref
		|		INNER JOIN Catalog.ProductsCharacteristics.AdditionalAttributes AS RowValue
		|		ON Variants.Characteristic = RowValue.Ref
		|WHERE
		|	ColumnValue.Property = &ColumnsCharacteristic
		|	AND RowValue.Property = &RowsCharacteristic
		|
		|GROUP BY
		|	Variants.Characteristic,
		|	ColumnValue.Value,
		|	RowValue.Value";
		
		Query.SetParameter("ColumnsCharacteristic", ColumnsCharacteristic);
		
	Else
		
		Query.Text = Query.Text + "
		|SELECT
		|	Variants.Characteristic AS Characteristic,
		|	RowValue.Value AS RowValue,
		|	UNDEFINED AS ColumnValue
		|FROM
		|	Variants AS Variants
		|		INNER JOIN Catalog.ProductsCharacteristics.AdditionalAttributes AS RowValue
		|		ON Variants.Characteristic = RowValue.Ref
		|WHERE
		|	RowValue.Property = &RowsCharacteristic
		|
		|GROUP BY
		|	Variants.Characteristic,
		|	RowValue.Value";
		
	EndIf;
	
	Query.SetParameter("Products", Products);
	Query.SetParameter("RowsCharacteristic", RowsCharacteristic);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		// Find row
		Filter = New Structure;
		Filter.Insert("Value", SelectionDetailRecords.RowValue);
		
		LinesWithRowName = RowsMap.FindRows(Filter);
		
		If LinesWithRowName.Count() > 0 Then
			
			Filter = New Structure;
			Filter.Insert("RowName", LinesWithRowName[0].Name);
			
			RowsToFill = List.FindRows(Filter);
			
			If RowsToFill.Count() > 0 Then
				
				RowToFill = RowsToFill[0];
				
				// Find column
				Filter = New Structure;
				Filter.Insert("Value", SelectionDetailRecords.ColumnValue);
				
				LinesWithColumnName = ColumnsMap.FindRows(Filter);
				
				If LinesWithColumnName.Count() > 0 Then
					
					ColumnName = LinesWithColumnName[0].Name;
					RowToFill[ColumnName] = True;
					
					VariantLine = CreatedVariants.Add();
					FillPropertyValues(VariantLine, SelectionDetailRecords);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure GenerateVariants()
	
	ClearMessages();
	
	Counter = 0;
	
	For Each ListRow In List Do
		
		Filter = New Structure;
		Filter.Insert("Name", ListRow.RowName);
		
		RowValues = RowsMap.FindRows(Filter);
		
		If RowValues.Count() Then
			
			RowValue = RowValues[0].Value;
			
			For Each ListColumn In ColumnsMap Do
				
				If ListRow[ListColumn.Name] Then
					
					Filter = New Structure;
					Filter.Insert("ColumnValue", ListColumn.Value);
					Filter.Insert("RowValue", RowValue);
					CreatedVariantsRows = CreatedVariants.FindRows(Filter);
					
					If CreatedVariantsRows.Count() = 0 Then
						
						NewVariant = CreateNewVariant(RowValue, ListColumn.Value);
						
						If ValueIsFilled(NewVariant) Then
							VariantLine = CreatedVariants.Add();
							VariantLine.Characteristic = NewVariant;
							VariantLine.ColumnValue = ListColumn.Value;
							VariantLine.RowValue = RowValue;
							
							Counter = Counter + 1;
						Else
							ListRow[ListColumn.Name] = False;
						EndIf;
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	ThisObject.Modified = False;
	
	MessageTemplate = NStr("en = '%1 new variants were created'; ru = 'Создано %1 новых вариантов';pl = '%1 nowe warianty zostali utworzone';es_ES = '%1se han creado nuevas variantes';es_CO = '%1se han creado nuevas variantes';tr = '%1 yeni varyant oluşturuldu';it = '%1 nuove varianti sono state create';de = '%1 neue Varianten wurden erstellt'");
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Counter);
	
	CommonClientServer.MessageToUser(MessageText);
	
EndProcedure

&AtServer
Function CreateNewVariant(RowValue, ColumnValue)
	
	NewVariant = Catalogs.ProductsCharacteristics.CreateItem();
	NewVariant.Owner = Products;
	NewVariant.Description = String(RowValue) 
		+ ?(ValueIsFilled(ColumnValue),
			", " + ColumnValue,
			"");
	
	RowProperty = NewVariant.AdditionalAttributes.Add();
	RowProperty.Property = RowsCharacteristic;
	RowProperty.Value = RowValue;
	
	ColumnProperty = NewVariant.AdditionalAttributes.Add();
	ColumnProperty.Property = ColumnsCharacteristic;
	ColumnProperty.Value = ColumnValue;
	
	Result = Catalogs.ProductsCharacteristics.EmptyRef();
	
	Try
		NewVariant.Write();
		Result = NewVariant.Ref;
	Except
		BriefErrorDescription = BriefErrorDescription(ErrorDescription());
		CommonClientServer.MessageToUser(BriefErrorDescription);
	EndTry;
	
	Return Result;
	
EndFunction

&AtServer
Procedure GenerateBarcodesAtServer()
	
	QueryTT = New Query;
	QueryTT.TempTablesManager = New TempTablesManager;
	QueryTT.Text = 
	"SELECT
	|	CreatedVariants.Characteristic AS Characteristic
	|INTO CreatedVariants
	|FROM
	|	&CreatedVariants AS CreatedVariants";
	
	QueryTT.SetParameter("CreatedVariants", CreatedVariants.Unload());
	QueryResult = QueryTT.Execute();
	
	Query = New Query;
	Query.TempTablesManager = QueryTT.TempTablesManager;
	Query.Text = 
	"SELECT
	|	CreatedVariants.Characteristic AS Characteristic
	|FROM
	|	CreatedVariants AS CreatedVariants
	|		LEFT JOIN InformationRegister.Barcodes AS Barcodes
	|		ON CreatedVariants.Characteristic = Barcodes.Characteristic
	|WHERE
	|	Barcodes.Characteristic IS NULL";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	Counter = 0;
	
	While SelectionDetailRecords.Next() Do
		
		BarcodeRecord = InformationRegisters.Barcodes.CreateRecordManager();
		BarcodeRecord.Barcode = InformationRegisters.Barcodes.GenerateBarcodeEAN13();
		BarcodeRecord.Products = Products;
		BarcodeRecord.Characteristic = SelectionDetailRecords.Characteristic;
		
		Try
			BarcodeRecord.Write();
			Counter = Counter + 1;
		Except
			BriefErrorDescription = BriefErrorDescription(ErrorDescription());
			CommonClientServer.MessageToUser(BriefErrorDescription);
		EndTry;
		
	EndDo;
	
	MessageTemplate = NStr("en = '%1 new barcodes were created'; ru = 'Создано %1 новых штрих-кодов';pl = '%1 nowe kody kreskowe zostali utworzone';es_ES = '%1se han creado nuevos códigos de barras';es_CO = '%1se han creado nuevos códigos de barras';tr = '%1 yeni barkod oluşturuldu';it = '%1 nuovi codici a barre sono stati creati';de = '%1 neue Barcodes wurden erstellt'");
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Counter);
	
	CommonClientServer.MessageToUser(MessageText);
	
EndProcedure

&AtClient
Procedure AfterUnsavedVariantsQuestion(Result, Parameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		GenerateVariants();
		GenerateBarcodesAtServer();
		
	EndIf;
	
EndProcedure

#EndRegion
