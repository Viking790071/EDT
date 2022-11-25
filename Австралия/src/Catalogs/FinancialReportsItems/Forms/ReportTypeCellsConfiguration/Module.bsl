#Region Variables

&AtClient
Var CopyPasteCache;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("MainStorageID", MainStorageID)
		Or Not Parameters.Property("ReportItems") Then
		MessageText = NStr("en = 'Direct opening of this form is not provided.'; ru = 'Непосредственное открытие данной формы не предусмотрено.';pl = 'Bezpośrednie otwarcie tego formularza nie jest przewidziane.';es_ES = 'La apertura directa de este formulario no está prevista.';es_CO = 'La apertura directa de este formulario no está prevista.';tr = 'Bu formun doğrudan açılması sağlanmamaktadır.';it = 'Non è fornita l''apertura diretta di questo modulo.';de = 'Ein direktes Öffnen dieses Formulars ist nicht vorgesehen.'");
		Raise MessageText;
	EndIf;
	
	FormData = Catalogs.FinancialReportsItems.FormOnCreateAtServer(ThisObject);
	ValueToFormAttribute(FormData.TableItems, "TableItems");
	
	Header = FormAttributeToValue("Object").GetTemplate("ConfigureCellsLegend");
	ReportPresentation.Clear();
	Legend = Header.GetArea("AreaLegend");
	ReportPresentation.Put(Legend);
	FirstRow = 2;
	
	ItemsTree = FormDataToValue(Parameters.ReportItems, Type("ValueTree"));
	ItemsTreeCopy = ItemsTree.Copy();
	ItemsTreeCopy.Rows.Clear();
	
	TreeRow = FinancialReportingClientServer.ChildItem(ItemsTree, "ItemStructureAddress", ItemAddressInTempStorage);
	
	TreeRow = FinancialReportingClientServer.RootItem(TreeRow, ItemType("TableComplex"));
	
	FinancialReportingClientServer.SetNewParent(TreeRow, ItemsTreeCopy, True, False);
	
	WidthStructure = Catalogs.FinancialReportsItems.OutputTableOfComplexTableSetting(ThisObject, ItemsTreeCopy);
	
	ReportItemsAddress = PutToTempStorage(ItemsTreeCopy, UUID);
	
	TemplateWidth = WidthStructure.TemplateWidth;
	TemplateHeight = WidthStructure.TemplateHeight;
	HeaderHeight  = WidthStructure.HeaderHeight;
	
	FormManagement();
	
	SetCellsColour();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	EditArea = GetEditArea(ThisObject);
	Total = EditArea.Right - EditArea.Left + 1;
	
	ReportPresentation.Area( , 2, , 2).ColumnWidth = 30;
	
	If Total Then
		OccupiedWidth = 0;
		For i = 1 To EditArea.Left - 1 Do
			OccupiedWidth = OccupiedWidth + ReportPresentation.Area( , i, , i).ColumnWidth;
		EndDo;
		TotalWidth = 120; //recommended table width
		FreeWidth = TotalWidth - OccupiedWidth;
		RecommendedColumnWidth = Max(Min(FreeWidth / Total, 30), 15);
		
		For i = EditArea.Left To EditArea.Right Do
			ReportPresentation.Area( , i, , i).ColumnWidth = RecommendedColumnWidth;
		EndDo;
	EndIf;
	
	ReportPresentation.FixedTop = GetEditArea(ThisObject).Top - 1;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Catalogs.FinancialReportsItems.FormBeforeWriteAtServer(ThisObject, CurrentObject, Cancel);
	If ValueIsFilled(ThisObject.ItemAddressInTempStorage) Then
		ItemStructure = GetFromTempStorage(ThisObject.ItemAddressInTempStorage);
		AddressInStorage = ReportItems();
		ItemStructure.TableItems = GetFromTempStorage(AddressInStorage);
		PutToTempStorage(ItemStructure, ThisObject.ItemAddressInTempStorage);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CellUseVariantPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("ItemTypeSelection", ThisObject);
	
	OpenForm("Catalog.FinancialReportsItems.Form.ReportIndicatorTypeSelection", , ThisObject,
		, , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure CellUseVariantPresentationClearing(Item, StandardProcessing)
	
	Area = Items.ReportPresentation.CurrentArea;
	If IsEditedArea(ThisObject, Area) Then
		CellUseVariantPresentationClearingAtServer();
		SetCellColour(Area);
	EndIf;
	
EndProcedure

&AtClient
Procedure FormulaOnChange(Item)
	
	Area = Items.ReportPresentation.CurrentArea;
	If IsEditedArea(ThisObject, Area) Then
		FormulaOnChangeAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure FormulaOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	ReportPresentationSelection(Undefined, Items.ReportPresentation.CurrentArea, Undefined);
	
EndProcedure

&AtClient
Procedure ReportPresentationOnActivate(Item)
	
	Area = Item.CurrentArea;
	Details = Area.Details;
	If Not IsEditedArea(ThisObject, Area)
		Or Details = Undefined
		Or TypeOf(Details) = Type("String")
		Or Details.ItemType = ItemType("Dimension")
		Or Details.ItemType = ItemType("Group")
		Or Details.ItemType = ItemType("GroupTotal") Then
		
		CellName = ""; Formula = "";
		Items.CellUseVariantPresentation.Enabled = False;
		FormManagement();
		Return;
		
	EndIf;
	
	If TypeOf(Details) = Type("Structure") Then
		
		Items.CellUseVariantPresentation.Enabled = True;
		Row 	= Details.Row.Description;
		Column = Details.Column.Description;
		CellName = "[" + Row + "; " + Column + "]";
		FormManagement();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportPresentationSelection(Item, Area, StandardProcessing)
	
	StandardProcessing = False;
	ShowAreaProperties(Area);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FinishEditing(Command)
	
	FinancialReportingClient.FinishEditingReportItem(ThisObject);
	
EndProcedure

&AtClient
Procedure Cut(Command)
	
	CopyValues(True);
	
EndProcedure

&AtClient
Procedure Paste(Command)
	
	If CopyPasteCache = Undefined Then
		Return;
	EndIf;
	
	MessageText = NStr("en = 'The selected area cannont be modified'; ru = 'Выбранная область не может быть изменена';pl = 'Wybranego obszaru nie można modyfikować';es_ES = 'El área seleccionada no puede ser modificada';es_CO = 'El área seleccionada no puede ser modificada';tr = 'Seçilen alanda değişiklik yapılamaz';it = 'L''area selezionata non può essere modificata';de = 'Der ausgewählte Bereich kann nicht geändert werden'");
	
	CurrentArea = Items.ReportPresentation.CurrentArea;
	If Not IsEditedArea(ThisObject, CurrentArea) Then
		ShowMessageBox( , MessageText);
		Return;
	EndIf;
	
	EditArea = GetEditArea(ThisObject);
	
	AreaHeight = CopyPasteCache.Count();
	AreaWidth = CopyPasteCache[0].Count();
	
	Cancel = False;
	
	If AreaHeight > 1 Or AreaWidth > 1 Then
		// Several cell in the "clipboard" - can only point where to paste
		If EditArea.Right < CurrentArea.Left + CopyPasteCache[0].UBound()
			Or EditArea.Bottom < CurrentArea.Top + CopyPasteCache.UBound() Then
			// Out of editable area
			Cancel = True;
		EndIf;
	Else
		// Only one cell in the "clipboard" - can paste anywhere within the editable area
		If Not IsEditedArea(ThisObject, CurrentArea) Then
			// Out of editable area
			Cancel = True;
		EndIf;
	EndIf;
	
	If Cancel Then
		ShowMessageBox( , MessageText);
		Return;
	EndIf;
	
	PasteAtServer(CopyPasteCache, AreaHeight, AreaWidth);
	
EndProcedure

&AtClient
Procedure Copy(Command)
	
	CopyValues();
	
EndProcedure

&AtClient
Procedure Clear(Command)
	
	ClearAtServer();
	
EndProcedure

&AtClient
Procedure Properties(Command)
	
	ShowAreaProperties(Items.ReportPresentation.CurrentArea)
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CopyValues(Cut = False)
	Var LocalCache;
	
	CurrentArea = Items.ReportPresentation.CurrentArea;
	
	If Not IsEditedArea(ThisObject, CurrentArea) Then
		ShowMessageBox(, NStr("en = 'Cannot copy the selected area'; ru = 'Не удается скопировать выбранную область';pl = 'Nie można skopiować wybranego obszaru';es_ES = 'El área seleccionada no se puede copiar';es_CO = 'El área seleccionada no se puede copiar';tr = 'Seçilen alan kopyalanamaz';it = 'Impossibile copiare l''area selezionata';de = 'Der ausgewählte Bereich kann nicht kopiert werden'"));
		Return;
	EndIf;
	
	AreaHeight = CurrentArea.Bottom - CurrentArea.Top + 1;
	AreaWidth = CurrentArea.Right - CurrentArea.Left + 1;
	
	Array = New Array(AreaHeight, AreaWidth);
	
	For HeightCounter = 0 To AreaHeight - 1 Do
		For WidthCounter = 0 To AreaWidth - 1 Do
			Area = ReportPresentation.Area(CurrentArea.Top + HeightCounter, CurrentArea.Left + WidthCounter);
			Array[HeightCounter][WidthCounter] = Area.Details.ReportItem;
			If Cut Then
				Area.Details.ReportItem = "";
				Area.Text = "<" + NStr("en = 'select cell type'; ru = 'выберите тип клетки';pl = 'wybierz typ komórek';es_ES = 'seleccione el tipo de celda';es_CO = 'seleccione el tipo de celda';tr = 'hücre tipini seç';it = 'seleziona tipo cella';de = 'Zelltyp auswählen'") + ">";
				SetCellColour(Area, LocalCache);
			EndIf;
		EndDo;
	EndDo;
	
	CopyPasteCache = Array;
	
EndProcedure

&AtServer
Procedure PasteAtServer(Array, AreaHeight, AreaWidth)
	Var LocalCache;
	
	CurrentArea = Items.ReportPresentation.CurrentArea;
	If Not (AreaWidth = 1 And AreaHeight = 1) Then
		If CurrentArea.Right - CurrentArea.Left + 1 <> AreaWidth
			Or CurrentArea.Bottom - CurrentArea.Top + 1 <> AreaHeight Then
			
			CurrentArea = ReportPresentation.Area(CurrentArea.Top, CurrentArea.Left,
			CurrentArea.Top + AreaHeight - 1,
			CurrentArea.Left + AreaWidth - 1);
			
		EndIf;
	EndIf;
	
	Items.ReportPresentation.CurrentArea = CurrentArea;
	
	For HeightCounter = CurrentArea.Top To CurrentArea.Bottom Do
		For WidthCounter = CurrentArea.Left To CurrentArea.Right Do
			
			Area = ReportPresentation.Area(HeightCounter, WidthCounter);
			
			If AreaWidth = 1 And AreaHeight = 1 Then
				ItemAddress = Array[0][0];
			Else
				ItemAddress = Array[HeightCounter - CurrentArea.Top][WidthCounter - CurrentArea.Left];
			EndIf;
			If ValueIsFilled(ItemAddress) Then
				ItemType = Undefined;
				Area.Details.ReportItem = FinancialReportingServerCall.CopyItemByAddress(ItemAddress, MainStorageID, ItemType);
				Area.Details.ItemType = ItemType;
			Else
				Area.Details.ReportItem = Undefined;
				Area.Details.ItemType = Undefined;
			EndIf;
			Catalogs.FinancialReportsItems.SetCellText(ThisObject, Area.Name);
			
		EndDo;
	EndDo;
	
	CurrentArea = Items.ReportPresentation.CurrentArea;
	
	For HeightCounter = CurrentArea.Top To CurrentArea.Bottom Do
		For WidthCounter = CurrentArea.Left To CurrentArea.Right Do
			
			Area = ReportPresentation.Area(HeightCounter, WidthCounter);
			SetCellColour(Area, LocalCache);
			
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure ClearAtServer()
	
	CurrentArea = Items.ReportPresentation.CurrentArea;
	For HeightCounter = CurrentArea.Top To CurrentArea.Bottom Do
		For WidthCounter = CurrentArea.Left To CurrentArea.Right Do
			
			Area = ReportPresentation.Area(HeightCounter, WidthCounter);
			If IsEditedArea(ThisObject, Area) Then
				Area.Details.ReportItem = Undefined;
				Area.Details.ItemType = Undefined;
				Catalogs.FinancialReportsItems.SetCellText(ThisObject, Area.Name);
				SetCellColour(Area);
			EndIf;
			
		EndDo;
	EndDo;
	
	FormManagement();
	
EndProcedure

&AtClient
Function DefineAdditionalParameters(Details)
	
	If Details.IsLinked Then
		Return PredefinedValue("Enum.ReportItemsAdditionalModes.LinkedItem");
	ElsIf Details.ItemType = ItemType("UserDefinedCalculatedIndicator") Then
		Return PredefinedValue("Enum.ReportItemsAdditionalModes.ReportType");
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function GetEditArea(Form)
	
	Result = New Structure;
	Result.Insert("Top",  4 + Form.HeaderHeight + 1); //the first row after header
	Result.Insert("Left",  3); //all the rows are in the second column, it means we edit starting with the third column
	Result.Insert("Bottom",   4 + Form.TemplateHeight); //till the last row
	Result.Insert("Right", 2 + Form.TemplateWidth); //till the last column
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function IsEditedArea(Form, Area)
	
	EditArea = GetEditArea(Form);
	If Area.Left >= EditArea.Left
		And Area.Right <= EditArea.Right
		And Area.Bottom <= EditArea.Bottom
		And Area.Top >= EditArea.Top Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Function TableCellProperties(PropertyName, ByDefault = Undefined)
	
	Area = Items.ReportPresentation.CurrentArea;
	Try
		Details = Area.Details;
	Except
		Return Undefined;
	EndTry;
	
	If Not ValueIsFilled(Details) Or TypeOf(Details) <> Type("Structure") Then
		Return ByDefault;
	EndIf;
	
	PropertyValue = Undefined;
	If Not Details.Property(PropertyName, PropertyValue) Then
		Return ByDefault;
	EndIf;
	
	Return PropertyValue;
	
EndFunction

&AtServer
Procedure FormManagement()
	
	ItemType = TableCellProperties("ItemType");
	ReportItem = TableCellProperties("ReportItem");
	IsLinked = TableCellProperties("IsLinked", False);
	
	CellValue = "";
	CellUseVariantPresentation = "";
	Formula = "";
	If ItemType = ItemType("AccountingDataIndicator")
		Or ItemType = ItemType("UserDefinedFixedIndicator") 
		Or ItemType = ItemType("UserDefinedCalculatedIndicator") Then
		
		Items.PagesItemTypePictures.CurrentPage = Items.PageReportItemPicture;
		ItemPicture = FinancialReportingCached.NonstandardPicture(ItemType) + Number(IsLinked);
		CellValue = FinancialReportingServerCall.ObjectAttributeValue(ReportItem, "DescriptionForPrinting");
		
	Else
		Items.PagesItemTypePictures.CurrentPage = Items.PageUndefinedPicture;
	EndIf;
	
	If ItemType = Undefined And ReportItem = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CellValue) Then
		CellUseVariantPresentation = CellUseVariantPresentation + " " + CellValue;
	EndIf;
	
	Items.Formula.Title = NStr("en = 'Setting'; ru = 'Настройка';pl = 'Ustawienia';es_ES = 'Configuración';es_CO = 'Configuración';tr = 'Ayarlar';it = 'Impostazione';de = 'Einstellung'");
	CaclulationString = NStr("en = 'Caclulation'; ru = 'Расчет';pl = 'Obliczenie';es_ES = 'Cálculo';es_CO = 'Cálculo';tr = 'Hesaplama';it = 'Calcolo';de = 'Kaklulation'");
	Items.Formula.Enabled = True;
	Formula = "";
	If IsLinked Then
		Formula = NStr("en = '<see the calculation in the linked item>'; ru = '<просмотр расчета в связанном элементе>';pl = '<patrz obliczenie w połączonym elemencie>';es_ES = '<ver el cálculo en el elemento relacionado>';es_CO = '<ver el cálculo en el elemento relacionado>';tr = '<bağlantılı ögedeki hesaplamayı gör>';it = '<vedi il calcolo nell''elemento collegato>';de = '<siehe die Kalkulation im verknüpften Element>.'");
		
	ElsIf ItemType = ItemType("UserDefinedCalculatedIndicator") Then
		
		Items.Formula.Title = CaclulationString;
		Formula = FinancialReportingServerCall.AdditionalAttributeValue(ReportItem, "Formula");
		
	ElsIf ItemType = ItemType("AccountingDataIndicator") Then
		
		Account = FinancialReportingServerCall.AdditionalAttributeValue(ReportItem, "Account");
		TotalsType = FinancialReportingServerCall.AdditionalAttributeValue(ReportItem, "TotalsType");
		OpeningBalance = FinancialReportingServerCall.AdditionalAttributeValue(ReportItem, "OpeningBalance");
		HasSettings = FinancialReportingServerCall.ObjectAttributeValue(ReportItem, "HasSettings");
		Formula = AccountingDataIndicatorShortName(Account, TotalsType, OpeningBalance);
		If HasSettings = True Then
			Formula = Formula + " <" + NStr("en = 'additional filter is set'; ru = 'дополнительный отбор установлен';pl = 'ustawiony jest dodatkowy filtr';es_ES = 'el filtro adicional está establecido';es_CO = 'el filtro adicional está establecido';tr = 'ek filtre ayarlanmıştır';it = 'filtro aggiuntivo impostato';de = 'zusätzlicher Filter ist gesetzt'") + ">";
		EndIf;
		
		If TypeOf(Account) = Type("ChartOfAccountsRef.FinancialChartOfAccounts") Then
			ItemPicture = FinancialReportingCached.NonstandardPicture(ItemType, "Fin") + Number(IsLinked);
		EndIf;
		
	ElsIf ItemType = ItemType("UserDefinedFixedIndicator") Then
		
		Formula = FinancialReportingServerCall.AdditionalAttributeValue(ReportItem, "UserDefinedFixedIndicator");
		
	ElsIf ItemType = ItemType("GroupTotal") Then
		
		Items.Formula.Title = CaclulationString;
		Formula = NStr("en = 'Sum'; ru = 'Сумма';pl = 'Suma';es_ES = 'Suma';es_CO = 'Suma';tr = 'Toplam';it = 'Somma';de = 'Summe'")+"()";
		Items.Formula.Enabled = False;
		ShowTitle = FinancialReportingServerCall.AdditionalAttributeValue(ReportItem, "OutputItemTitle");
		If Not ShowTitle Then
			Formula = NStr("en = '<not shown in the report>'; ru = '<не отображается в отчете>';pl = '<nie pokazane w raporcie>';es_ES = '<no se muestra en el informe>';es_CO = '<no se muestra en el informe>';tr = '<raporda gösterilmez>';it = '<non mostrato nel report>';de = '<nicht im Bericht angezeigt>'");
		EndIf;
		
	ElsIf ItemType = ItemType("Group") Then
		
		Items.Formula.Enabled = False;
		ShowTitle = FinancialReportingServerCall.AdditionalAttributeValue(ReportItem, "OutputItemTitle");
		If Not ShowTitle Then
			Formula = NStr("en = '<not shown in the report>'; ru = '<не отображается в отчете>';pl = '<nie pokazane w raporcie>';es_ES = '<no se muestra en el informe>';es_CO = '<no se muestra en el informe>';tr = '<raporda gösterilmez>';it = '<non mostrato nel report>';de = '<nicht im Bericht angezeigt>'");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetCellValue(Result)
	
	ItemStructure = FinancialReportingClientServer.ReportItemStructure();
	FillPropertyValues(ItemStructure, Result);
	
	If Result.IsLinked Then
		
		FinancialReportingServerCall.SetAdditionalAttributeValue(ItemStructure, "RowCode", "");
		FinancialReportingServerCall.SetAdditionalAttributeValue(ItemStructure, "Note", "");
		
	ElsIf ItemStructure.ItemType = ItemType("AccountingDataIndicator") Then
		
		FinancialReportingServerCall.SetAdditionalAttributeValue(ItemStructure, "Account", Result.ReportItem);
		FinancialReportingServerCall.SetAdditionalAttributeValue(ItemStructure, "TotalsType", Enums.TotalsTypes.BalanceDr);
		FinancialReportingServerCall.SetAdditionalAttributeValue(ItemStructure, "OpeningBalance", False);
		
	ElsIf ItemStructure.ItemType = ItemType("UserDefinedFixedIndicator") Then
		
		FinancialReportingServerCall.SetAdditionalAttributeValue(ItemStructure, "UserDefinedFixedIndicator", Result.ReportItem);
		
	EndIf;
	
	ItemRef = FinancialReportingClientServer.PutItemToTempStorage(ItemStructure, MainStorageID);
	
	CurrentArea = Items.ReportPresentation.CurrentArea;
	Details = CurrentArea.Details;
	Details.ItemType = ItemStructure.ItemType;
	Details.ReportItem = ItemRef;
	Details.IsLinked = Result.IsLinked;
	
	FormManagement();
	Catalogs.FinancialReportsItems.SetCellText(ThisObject, CurrentArea.Name);
	
EndProcedure

&AtClient
Procedure ItemTypeSelection(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Area = Items.ReportPresentation.CurrentArea;
	Area.Font = New Font( , , False);
	SetCellValue(Result);
	SetCellColour(Area);
	
	If Not Result.IsLinked
		And Area.Details.ItemType = PredefinedValue("Enum.FinancialReportItemsTypes.UserDefinedCalculatedIndicator") Then
		EditReportItem(Area);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetCellColour(Area, LocalCache = Undefined)
	
	CellDetails = Area.Details;
	If Not ValueIsFilled(CellDetails.ReportItem) And Not ValueIsFilled(CellDetails.ItemType) Then
		
		Area.BackColor = FinancialReportingClientServer.GetStyleColor(LocalCache, "DeletedAttributeBackground");
		Area.TextColor = FinancialReportingClientServer.GetStyleColor(LocalCache, "InaccessibleDataColor");
		Area.Font = New Font( , , True);
		Area.HorizontalAlign	= HorizontalAlign.Center;
		Area.VerticalAlign	= VerticalAlign.Center;
		
	Else
		
		Area.BackColor = FinancialReportingClientServer.GetStyleColor(LocalCache, "FieldBackColor");
		Area.TextColor = FinancialReportingClientServer.GetStyleColor(LocalCache, "FieldTextColor");
		Area.Font = New Font(,,False);
		Area.HorizontalAlign	= HorizontalAlign.Left;
		Area.VerticalAlign	= VerticalAlign.Top;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetCellsColour()
	Var LocalCache;
	
	EditArea = GetEditArea(ThisObject);
	For Column = EditArea.Left To EditArea.Right Do
		For Row = EditArea.Top To EditArea.Bottom Do
			Area = ReportPresentation.Area(Row, Column);
			SetCellColour(Area, LocalCache);
		EndDo;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function ItemType(ItemTypeName)
	
	Return PredefinedValue("Enum.FinancialReportItemsTypes." + ItemTypeName);
	
EndFunction

&AtClient
Procedure ShowAreaProperties(Area)
	
	Details = Area.Details;
	If Details = Undefined
		Or TypeOf(Details) = Type("String")
		Or Details.ItemType = ItemType("Dimension")
		Or Details.ItemType = ItemType("Group")
		Or Details.ItemType = ItemType("GroupTotal") Then
		Return;
	EndIf;
	If IsEditedArea(ThisObject, Area) Then
		
		If Not ValueIsFilled(Details.ReportItem) Then
			CellUseVariantPresentationStartChoice(Undefined, Undefined, Undefined);
		Else
			EditReportItem(Area);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditReportItem(Area)
	
	Details = Area.Details;
	
	If Details.ItemType = PredefinedValue("Enum.FinancialReportItemsTypes.Group")
		Or Details.ItemType = PredefinedValue("Enum.FinancialReportItemsTypes.Dimension")
		Or Details.ItemType = PredefinedValue("Enum.FinancialReportItemsTypes.GroupTotal") Then
		ShowMessageBox(Undefined, NStr("en = 'Item properties setting is available in the report type form'; ru = 'Настройка свойств элемента доступна в форме типа отчета';pl = 'Ustawienie właściwości elementu jest dostępne w formularzu typu raportu';es_ES = 'La configuración de las propiedades del elemento está disponible en el formulario de tipo de informe';es_CO = 'La configuración de las propiedades del elemento está disponible en el formulario de tipo de informe';tr = 'Öge özellikleri ayarı rapor türü biçiminde kullanılabilir';it = 'L''impostazione proprietà elemento è disponibile nel modulo del tipo di report';de = 'Die Einstellung der Elementeigenschaften ist im Formular für den Berichtstyp verfügbar'"));
		Return;
	EndIf;
	
	ItemStructureAddress = Details.ReportItem;
	
	FormParameters = New Structure();
	FormParameters.Insert("ItemType",					Details.ItemType);
	FormParameters.Insert("ItemAddressInTempStorage",	ItemStructureAddress);
	FormParameters.Insert("MainStorageID",				MainStorageID);
	FormParameters.Insert("ConfigureCells",				True);
	FormParameters.Insert("ItemsTableAddress",			ReportItems());
	FormParameters.Insert("ReportItemsAddress",			ReportItemsAddress);
	FormParameters.Insert("AdditionalFormMode",			DefineAdditionalParameters(Details));
	
	Notification = New NotifyDescription("RefreshFieldAfterItemModification", ThisObject, FormParameters);
	
	OpenForm("Catalog.FinancialReportsItems.ObjectForm",
		FormParameters, ThisObject, , , , Notification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Procedure RefreshInformationAfterReportItemModification(Name)
	
	Catalogs.FinancialReportsItems.SetCellText(ThisObject, Name);
	FormManagement();
	
EndProcedure

&AtClient
Procedure RefreshFieldAfterItemModification(Result, AdditionalParameters) Export
	
	RefreshInformationAfterReportItemModification(Items.ReportPresentation.CurrentArea.Name);
	
EndProcedure

&AtServer
Procedure FormulaOnChangeAtServer()
	
	Area = Items.ReportPresentation.CurrentArea;
	FinancialReportingServerCall.SetAdditionalAttributeValue(Area.Details.ReportItem, "Formula", Formula);
	Catalogs.FinancialReportsItems.SetCellText(ThisObject, Area.Name);
	
EndProcedure

&AtServer
Procedure CellUseVariantPresentationClearingAtServer()
	
	Area = Items.ReportPresentation.CurrentArea;
	Area.Details.ReportItem = Undefined;
	Area.Details.ItemType = Undefined;
	Catalogs.FinancialReportsItems.SetCellText(ThisObject, Area.Name);
	FormManagement();
	
EndProcedure

&AtServer
Function ReportItems()
	
	EditArea = GetEditArea(ThisObject);
	TableItemsCopy = New ValueTable;
	TableItemsCopy.Columns.Add("Row");
	TableItemsCopy.Columns.Add("Column");
	TableItemsCopy.Columns.Add("Item");
	For Column = EditArea.Left To EditArea.Right Do
		For Row = EditArea.Top To EditArea.Bottom Do
			Details = ReportPresentation.Area(Row, Column).Details;
			If ValueIsFilled(Details.ReportItem)
				And Not Details.ItemType = Enums.FinancialReportItemsTypes.GroupTotal
				And Not Details.ItemType = Enums.FinancialReportItemsTypes.Group Then
				
				NewRow = TableItemsCopy.Add();
				NewRow.Row = Details.Row.ReportItem;
				NewRow.Column = Details.Column.ReportItem;
				NewRow.Item = Details.ReportItem;
				
			EndIf;
		EndDo;
	EndDo;
	
	Return PutToTempStorage(TableItemsCopy, UUID);
	
EndFunction

&AtServer
Function AccountingDataIndicatorShortName(Account, TotalsType, OpeningBalance)
	
	If TotalsType = Enums.TotalsTypes.Balance Then
		If OpeningBalance Then
			ShortNamePattern = NStr("en = '%1 account opening balance'; ru = '%1 начальный остаток на счете';pl = '%1 saldo otwarcia konta';es_ES = '%1 saldo de apertura de cuenta';es_CO = '%1 saldo de apertura de cuenta';tr = '%1 hesabı açılış bakiyesi';it = 'Conto %1 bilancio di apertura';de = '%1 Kontoanfangssaldo'");
		Else
			ShortNamePattern = NStr("en = '%1 account closing balance'; ru = '%1 конечный остаток на счете';pl = '%1 saldo końcowe konta';es_ES = '%1 saldo final de cuenta';es_CO = '%1 saldo final de cuenta';tr = '%1 hesap kapanış bakiyesi';it = 'saldo di chiusura conto %1';de = '%1 Kontoabschlusssaldo'");
		EndIf;
	ElsIf TotalsType = Enums.TotalsTypes.BalanceDr Then
		If OpeningBalance Then
			ShortNamePattern = NStr("en = '%1 account opening Dr balance'; ru = '%1 начальный Дт остаток на счете';pl = '%1 saldo otwarcia konta Wn';es_ES = '%1 saldo de débito de apertura de cuenta';es_CO = '%1 saldo de débito de apertura de cuenta';tr = '%1 hesap açılış borç bakiyesi';it = 'saldo di apertura Deb conto %1';de = '%1 Kontoeröffnung Soll-Saldo'");
		Else
			ShortNamePattern = NStr("en = '%1 account closing Dr balance'; ru = '%1 конечный Дт остаток на счете';pl = '%1 saldo końcowe konta Wn';es_ES = '%1 saldo de débito final de cuenta';es_CO = '%1 saldo de débito final de cuenta';tr = '%1 hesap kapanış borç bakiyesi';it = 'saldo di chiusura Deb conto %1';de = '%1 Kontenabschluss Soll-Saldo'");
		EndIf;
	ElsIf TotalsType = Enums.TotalsTypes.BalanceCr Then
		If OpeningBalance Then
			ShortNamePattern = NStr("en = '%1 account opening Cr balance'; ru = '%1 начальный Кт остаток на счете';pl = '%1 saldo otwarcia Ma konta';es_ES = '%1  saldo de crédito de apertura de cuenta';es_CO = '%1  saldo de crédito de apertura de cuenta';tr = '%1 hesap açılış alacak bakiyesi';it = 'saldo di apertura Cred conto %1';de = '%1 Haben-Anfangssaldo des Kontos'");
		Else
			ShortNamePattern = NStr("en = '%1 account closing Cr balance'; ru = '%1 конечный Кт остаток на счете';pl = '%1 saldo końcowe Ma konta';es_ES = '%1  saldo de crédito final de cuenta';es_CO = '%1  saldo de crédito final de cuenta';tr = '%1 hesap kapanış alacak bakiyesi';it = 'saldo di chiusura Cred conto %1';de = '%1 Haben-Abschlusssaldo des Kontos'");
		EndIf;
	Else
		ShortNamePattern = NStr("en = '%1 account turnover'; ru = '%1 оборот по счету';pl = '%1 obrót konta';es_ES = '%1 movimiento de cuentas';es_CO = '%1 movimiento de cuentas';tr = '%1 hesap devir hızı';it = 'fatturato conto %1';de = '%1 Kontoumsatz'");
	EndIf;
	
	ShortName = StringFunctionsClientServer.SubstituteParametersToString(ShortNamePattern, String(Account));
	
	Return ShortName;
	
EndFunction

#EndRegion
