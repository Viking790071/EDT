
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping initialization to guarantee receiving of the form when passing the Autotest parameter.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Formula         = Parameters.Formula;
	SourceFormula = Parameters.Formula;
	
	Parameters.Property("UsesOperandTree", UsesOperandTree);
	
	Items.OperandsPagesGroup.CurrentPage = Items.NumericOperandsPage;
	Operands.Load(GetFromTempStorage(Parameters.Operands));
	For Each curRow In Operands Do
		If curRow.DeletionMark Then
			curRow.PictureIndex = 3;
		Else
			curRow.PictureIndex = 2;
		EndIf;
	EndDo;
	
	OperatorsTree = GetStandardOperatorsTree();
	ValueToFormAttribute(OperatorsTree, "Operators");
	
	If Parameters.Property("OperandsTitle") Then
		Items.OperandsGroup.Title = Parameters.OperandsTitle;
		Items.OperandsGroup.ToolTip = Parameters.OperandsTitle;
	EndIf;
	
	SetFormItemProperty(
			Items,
			"Operands",
			"ChangeRowSet",
			False);
	
	SetVisibility();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	StandardProcessing = False;
	If Not Modified Or Not ValueIsFilled(SourceFormula) Or SourceFormula = Formula Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("BeforeCloseCompletion", ThisObject), NStr("ru='Данные были изменены. Сохранить изменения?'; en = 'The data was changed. Do you want to save the changes?'; pl = 'Dane zostały zmienione. Czy chcesz zapisać zmiany?';es_ES = 'Datos se han cambiado. ¿Quiere guardar los cambios?';es_CO = 'Datos se han cambiado. ¿Quiere guardar los cambios?';tr = 'Veriler değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'I dati sono stati modificati. Volete salvare le modifiche?';de = 'Daten wurden geändert. Wollen Sie die Änderungen speichern?'"), QuestionDialogMode.YesNoCancel);
	
EndProcedure

&AtClient
Procedure BeforeCloseCompletion(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	If Response = DialogReturnCode.Yes Then
		If CheckFormula(Formula, Operands()) Then
			Modified = False;
			Close(Formula);
		EndIf;
	ElsIf Response = DialogReturnCode.No Then
		Modified = False;
		Close(Undefined);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SettingsComposerSettingsChoiceAvailableChoiceFieldsChoice(Item, RowSelected, Field, StandardProcessing)
	
	StringText = String(SettingsComposer.Settings.OrderAvailableFields.GetObjectByID(RowSelected).Field);
	Operand = ProcessOperandText(StringText);
	InsertTextIntoFormula(Operand);
	
EndProcedure

&AtClient
Procedure SettingsComposerStartDrag(Item, DragParameters, Perform)
	
	ItemText = String(SettingsComposer.Settings.OrderAvailableFields.GetObjectByID(Items.SettingsComposer.CurrentRow).Field);
	DragParameters.Value = ProcessOperandText(ItemText);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperands

&AtClient
Procedure OperandsChoice(Item, RowSelected, Field, StandardProcessing)
	
	If Field.Name = "OperandsValues" Then
		Return;
	EndIf;
	
	If Item.CurrentData.DeletionMark Then
		
		ShowQueryBox(
			New NotifyDescription("OperandsSelectCompletion", ThisObject), 
			NStr("ru = 'Выбранный элемент помечен на удаление. 
				|Продолжить?'; 
				|en = 'The selected item is marked for deletion. 
				|Continue?'; 
				|pl = 'Wybrany element został zaznaczony do usunięcia. 
				|Kontynuować?';
				|es_ES = 'Elemento seleccionado marcado para borrar. 
				|¿Continuar?';
				|es_CO = 'Elemento seleccionado marcado para borrar. 
				|¿Continuar?';
				|tr = 'Seçilmiş öğe silinmek için işaretlendi. 
				|Devam et?';
				|it = 'L''elemento selezionato è contrassegnato per l''eliminazione. 
				|Continuare?';
				|de = 'Das ausgewählte Element wird zum Löschen vorgemerkt.
				|Fortsetzen?'"), 
			QuestionDialogMode.YesNo);
		StandardProcessing = False;
		Return;
	EndIf;
	
	StandardProcessing = False;
	InsertOperandIntoFormula();
	
EndProcedure

&AtClient
Procedure OperandsSelectCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		InsertOperandIntoFormula();
	EndIf;

EndProcedure

&AtClient
Procedure OperandsStartDrag(Item, DragParameters, Perform)
	
	DragParameters.Value = GetOperandTextToInsert(Item.CurrentData.ID);
	
EndProcedure

&AtClient
Procedure OperandsEndDrag(Item, DragParameters, StandardProcessing)
	
	If Item.CurrentData.DeletionMark Then
		ShowQueryBox(New NotifyDescription("OperandsDragEndCompletion", ThisObject), NStr("ru = 'Выбранный элемент помечен на удаление'; en = 'The selected item is marked for deletion'; pl = 'Wybrany element został zaznaczony do usunięcia';es_ES = 'Elemento seleccionado marcado para borrar';es_CO = 'Elemento seleccionado marcado para borrar';tr = 'Seçilmiş öğe silinmek için işaretlendi';it = 'L''elemento selezionato è contrassegnato per l''eliminazione';de = 'Das ausgewählte Element wird zum Löschen vorgemerkt'") + Chars.LF + NStr("ru = 'Продолжить?'; en = 'Continue?'; pl = 'Kontynuować?';es_ES = '¿Continuar?';es_CO = '¿Continuar?';tr = 'Devam et?';it = 'Continuare?';de = 'Fortsetzen?'"), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure OperandsDragEndCompletion(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	
	If Response = DialogReturnCode.No Then
		
		StringBeginning  = 0;
		BeginningOfTheColumn = 0;
		EndOfLine   = 0;
		EndOfTheColumn  = 0;
		
		Items.Formula.GetTextSelectionBounds(StringBeginning, BeginningOfTheColumn, EndOfLine, EndOfTheColumn);
		Items.Formula.SelectedText = "";
		Items.Formula.SetTextSelectionBounds(StringBeginning, BeginningOfTheColumn, StringBeginning, BeginningOfTheColumn);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OperandsTreeChoice(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Items.OperandsTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ParentRow = CurrentData.GetParent();
	If ParentRow = Undefined Then
		Return;
	EndIf;
	
	InsertTextIntoFormula(GetOperandTextToInsert(
		ParentRow.ID + "." + CurrentData.ID));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperandsTree

&AtClient
Procedure OperandsTreeStartDrag(Item, DragParameters, Perform)
	
	If DragParameters.Value = Undefined Then
		Return;
	EndIf;
	
	TreeRow = OperandsTree.FindByID(DragParameters.Value);
	ParentRow = TreeRow.GetParent();
	If ParentRow = Undefined Then
		Perform = False;
		Return;
	Else
		DragParameters.Value = 
		   GetOperandTextToInsert(ParentRow.ID +"." + TreeRow.ID);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperators

&AtClient
Procedure OperatorsChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	InsertOperatorIntoFormula();
	
EndProcedure

&AtClient
Procedure OperatorsStartDrag(Item, DragParameters, Perform)
	
	If ValueIsFilled(Item.CurrentData.Operator) Then
		DragParameters.Value = Item.CurrentData.Operator;
	Else
		Perform = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OperatorsEndDrag(Item, DragParameters, StandardProcessing)
	
	If Item.CurrentData.Operator = "Format(,)" Then
		RowFormat = New FormatStringWizard;
		RowFormat.Show(New NotifyDescription("OperatorsEndDragCompletion", ThisObject, New Structure("RowFormat", RowFormat)));
	EndIf;
	
EndProcedure

&AtClient
Procedure OperatorsEndDragCompletion(Text, AdditionalParameters) Export
	
	RowFormat = AdditionalParameters.RowFormat;
	
	
	If ValueIsFilled(RowFormat.Text) Then
		TextForInput = "Format( , """ + RowFormat.Text + """)";
		Items.Formula.SelectedText = TextForInput;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	
	If CheckFormula(Formula, Operands()) Then
		Close(Formula);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckSSL(Command)
	
	ClearMessages();
	CheckFormulaInteractive(Formula, Operands());
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure InsertTextIntoFormula(TextForInput, Offset = 0)
	
	RowStart = 0;
	RowEnd = 0;
	ColumnStart = 0;
	ColumnEnd = 0;
	
	Items.Formula.GetTextSelectionBounds(RowStart, ColumnStart, RowEnd, ColumnEnd);
	
	If (ColumnEnd = ColumnStart) AND (ColumnEnd + StrLen(TextForInput)) > Items.Formula.Width / 8 Then
		Items.Formula.SelectedText = "";
	EndIf;
		
	Items.Formula.SelectedText = TextForInput;
	
	If Not Offset = 0 Then
		Items.Formula.GetTextSelectionBounds(RowStart, ColumnStart, RowEnd, ColumnEnd);
		Items.Formula.SetTextSelectionBounds(RowStart, ColumnStart - Offset, RowEnd, ColumnEnd - Offset);
	EndIf;
		
	CurrentItem = Items.Formula;
	
EndProcedure

&AtClient
Procedure InsertOperandIntoFormula()
	
	InsertTextIntoFormula(GetOperandTextToInsert(Items.Operands.CurrentData.ID));
	
EndProcedure

&AtClient
Function Operands()
	
	Result = New Array();
	For Each Operand In Operands Do
		Result.Add(Operand.ID);
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure InsertOperatorIntoFormula()
	
	If Items.Operators.CurrentData.Description = "Format" Then
		RowFormat = New FormatStringWizard;
		RowFormat.Show(New NotifyDescription("InsertOperatorIntoFormulaCompletion", ThisObject, New Structure("RowFormat", RowFormat)));
		Return;
	Else	
		InsertTextIntoFormula(Items.Operators.CurrentData.Operator, Items.Operators.CurrentData.Offset);
	EndIf;
	
EndProcedure

&AtClient
Procedure InsertOperatorIntoFormulaCompletion(Text, AdditionalParameters) Export
	
	RowFormat = AdditionalParameters.RowFormat;
	
	If ValueIsFilled(RowFormat.Text) Then
		TextForInput = "Format( , """ + RowFormat.Text + """)";
		InsertTextIntoFormula(TextForInput, Items.Operators.CurrentData.Offset);
	Else	
		InsertTextIntoFormula(Items.Operators.CurrentData.Operator, Items.Operators.CurrentData.Offset);
	EndIf;
	
EndProcedure

&AtClient
Function ProcessOperandText(OperandText)
	
	StringText = OperandText;
	StringText = StrReplace(StringText, "[", "");
	StringText = StrReplace(StringText, "]", "");
	Operand = "[" + StrReplace(StringText, 
		?(PropertySet.ProductPropertiesSet, "Products.", 
			?(NOT PropertySet.Property("CharacteristicsPropertySet") OR PropertySet.CharacteristicsPropertySet, "ProductCharacteristic.", "ProductSeries.")), "") + "]";
	
	Return Operand
	
EndFunction

&AtClient
Procedure FormulaOnChange(Item)
	
	If Advanced Then
		Presentation = "";
	EndIf;
	
	If EnableValue Then
		SetFormulaCalculationPresentation(Formula, Operands, Calculation);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetVisibility()

	SetFormItemProperty(
		Items,
		"OperandsIDs",
		"Visible",
		Not Advanced);
	
	SetFormItemProperty(
		Items,
		"OperandsPresentation",
		"Visible",
		Advanced);
	
	SetFormItemProperty(
		Items,
		"OperandsValues",
		"Visible",
		EnableValue);
		
	SetFormItemProperty(
		Items,
		"Calculation",
		"Visible",
		EnableValue);
		
	SetFormItemProperty(
		Items,
		"AutoAmountDecoration",
		"Visible",
		EnableValue);
		
	SetFormItemProperty(
		Items,
		"Operands",
		"Header",
		EnableValue);
		
	SetFormItemProperty(
		Items,
		"Operators",
		"Header",
		EnableValue);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFormulaCalculationPresentation(Val CalculationFormula, Operands, Presentation)
	
	If Not ValueIsFilled(CalculationFormula) Then
		Presentation = "";
		Return;
	EndIf;
	
	CalculationFormula = RemoveInsignificantCharacters(CalculationFormula);
	OutputIntermediateCalculations = False;
	
	OperandsArray = TextFormulaOperands(CalculationFormula);
	
	For each Operand In OperandsArray Do
		RowsFound = Operands.FindRows(New Structure("ID", Operand));
		If RowsFound.Count() = 1 Then
			If NOT OutputIntermediateCalculations Then
				OutputIntermediateCalculations = NOT IsBlankString(RemoveInsignificantCharacters(StrReplace(CalculationFormula, "["+Operand+"]", "")));
			EndIf;
			CalculationFormula = StrReplace(CalculationFormula, "["+Operand+"]", Format(RowsFound[0].Value, "NDS=.; NZ=0; NG=0"));
		EndIf;
	EndDo;
	
	Try
		CalculationResult = Format(Eval(CalculationFormula),"ND=15; NFD=3; NZ=0");
	Except
		Return;
	EndTry;
	
	Presentation = ?(OutputIntermediateCalculations, CalculationFormula, "") + ?(ValueIsFilled(CalculationFormula), " = ", "") + CalculationResult;
	
	Presentation = RemoveInsignificantCharacters(Presentation);
	
EndProcedure

&AtClientAtServerNoContext
Function RemoveInsignificantCharacters(Val IncomingString)
	
	IncomingString = TrimAll(IncomingString);
	StringLength = StrLen(IncomingString);
	EndString = String("");
	
	While StringLength > 0 Do 
		
		FirstChar = Left(IncomingString, 1);
		
		If Not IsBlankString(FirstChar) Then
			EndString = EndString + FirstChar;
			StringLength = StringLength - 1;
			Indent = 2;
		Else
			EndString = EndString + " ";
			IncomingString = TrimL(IncomingString);
			StringLength = StrLen(IncomingString);
			Indent = 1;
		EndIf;
		
		If StringLength > 1 Then
			IncomingString = Mid(IncomingString, Indent, StringLength);
		Else
			EndString = EndString + Mid(IncomingString, Indent, 1);
			StringLength = 0; 
		EndIf;
		
	EndDo;
	
	Return EndString;
	
EndFunction

&AtServer
Function GetEmptyOperatorsTree()
	
	Tree = New ValueTree();
	Tree.Columns.Add("Description");
	Tree.Columns.Add("Operator");
	Tree.Columns.Add("Offset", New TypeDescription("Number"));
	
	Return Tree;
	
EndFunction

&AtServer
Function AddOperatorsGroup(Tree, Description)
	
	NewGroup = Tree.Rows.Add();
	NewGroup.Description = Description;
	
	Return NewGroup;
	
EndFunction

&AtServer
Function AddOperator(Tree, Parent, Description, Operator = Undefined, Offset = 0)
	
	NewRow = ?(Parent <> Undefined, Parent.Rows.Add(), Tree.Rows.Add());
	NewRow.Description = Description;
	NewRow.Operator = ?(ValueIsFilled(Operator), Operator, Description);
	NewRow.Offset = Offset;
	
	Return NewRow;
	
EndFunction

&AtServer
Function GetStandardOperatorsTree()
	
	Tree = GetEmptyOperatorsTree();
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("ru='Разделители'; en = 'Separators'; pl = 'Separatory';es_ES = 'Separadores';es_CO = 'Separadores';tr = 'Ayırıcılar';it = 'Separatori';de = 'Trennzeichen'"));
	
	AddOperator(Tree, OperatorsGroup, "/", " + ""/"" + ");
	AddOperator(Tree, OperatorsGroup, "\", " + ""\"" + ");
	AddOperator(Tree, OperatorsGroup, "|", " + ""|"" + ");
	AddOperator(Tree, OperatorsGroup, "_", " + ""_"" + ");
	AddOperator(Tree, OperatorsGroup, ",", " + "", "" + ");
	AddOperator(Tree, OperatorsGroup, ".", " + "". "" + ");
	AddOperator(Tree, OperatorsGroup, NStr("ru='Пробел'; en = 'Space'; pl = 'Spacja';es_ES = 'Espacio';es_CO = 'Espacio';tr = 'Boşluk';it = 'Space';de = 'Leertaste'"), " + "" "" + ");
	AddOperator(Tree, OperatorsGroup, "(", " + "" ("" + ");
	AddOperator(Tree, OperatorsGroup, ")", " + "") "" + ");
	AddOperator(Tree, OperatorsGroup, """", " + """""""" + ");
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("ru='Операторы'; en = 'Operators'; pl = 'Operatorzy';es_ES = 'Operadores';es_CO = 'Operadores';tr = 'Operatörler';it = 'Operatori';de = 'Operatoren'"));
	
	AddOperator(Tree, OperatorsGroup, "+", " + ");
	AddOperator(Tree, OperatorsGroup, "-", " - ");
	AddOperator(Tree, OperatorsGroup, "*", " * ");
	AddOperator(Tree, OperatorsGroup, "/", " / ");
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("ru='Логические операторы и константы'; en = 'Logical operators and constants'; pl = 'Operatory logiczne i konstanty';es_ES = 'Operadores lógicos y constantes';es_CO = 'Operadores lógicos y constantes';tr = 'Mantıksal işleçler ve sabitler';it = 'Operatori logici e costanti';de = 'Logische Operatoren und Konstanten'"));
	AddOperator(Tree, OperatorsGroup, "<", " < ");
	AddOperator(Tree, OperatorsGroup, ">", " > ");
	AddOperator(Tree, OperatorsGroup, "<=", " <= ");
	AddOperator(Tree, OperatorsGroup, ">=", " >= ");
	AddOperator(Tree, OperatorsGroup, "=", " = ");
	AddOperator(Tree, OperatorsGroup, "<>", " <> ");
	AddOperator(Tree, OperatorsGroup, NStr("ru='И'; en = 'AND'; pl = 'AND';es_ES = 'Y';es_CO = 'Y';tr = 'VE';it = 'E';de = 'UND'"),      " " + NStr("ru='И'; en = 'AND'; pl = 'AND';es_ES = 'Y';es_CO = 'Y';tr = 'VE';it = 'E';de = 'UND'")      + " ");
	AddOperator(Tree, OperatorsGroup, NStr("ru='Или'; en = 'Or'; pl = 'Lub';es_ES = 'O';es_CO = 'O';tr = 'Veya';it = 'O';de = 'Oder'"),    " " + NStr("ru='Или'; en = 'Or'; pl = 'Lub';es_ES = 'O';es_CO = 'O';tr = 'Veya';it = 'O';de = 'Oder'")    + " ");
	AddOperator(Tree, OperatorsGroup, NStr("ru='Не'; en = 'Not'; pl = 'Nie';es_ES = 'No';es_CO = 'No';tr = 'Değil';it = 'No';de = 'Nicht'"),     " " + NStr("ru='Не'; en = 'Not'; pl = 'Nie';es_ES = 'No';es_CO = 'No';tr = 'Değil';it = 'No';de = 'Nicht'")     + " ");
	AddOperator(Tree, OperatorsGroup, NStr("ru='True'; en = 'TRUE'; pl = 'TRUE';es_ES = 'VERDADERO';es_CO = 'VERDADERO';tr = 'TRUE';it = 'TRUE';de = 'WAHR'"), " " + NStr("ru='True'; en = 'TRUE'; pl = 'TRUE';es_ES = 'VERDADERO';es_CO = 'VERDADERO';tr = 'TRUE';it = 'TRUE';de = 'WAHR'") + " ");
	AddOperator(Tree, OperatorsGroup, NStr("ru='False'; en = 'FALSE'; pl = 'FALSE';es_ES = 'FALSO';es_CO = 'FALSO';tr = 'FALSE';it = 'FALSO';de = 'FALSE'"),   " " + NStr("ru='False'; en = 'FALSE'; pl = 'FALSE';es_ES = 'FALSO';es_CO = 'FALSO';tr = 'FALSE';it = 'FALSO';de = 'FALSE'")   + " ");
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("ru='Числовые функции'; en = 'Numerical functions'; pl = 'Funkcje liczbowe';es_ES = 'Funciones numéricas';es_CO = 'Funciones numéricas';tr = 'Rakamsal işlevler';it = 'Funzioni numeriche';de = 'Numerische Funktionen'"));
	
	AddOperator(Tree, OperatorsGroup, NStr("ru='Максимум'; en = 'Maximum'; pl = 'Maksimum';es_ES = 'Máximo';es_CO = 'Máximo';tr = 'Maksimum';it = 'Massimo';de = 'Maximum'"),    NStr("ru='Макс(,)'; en = 'Max(,)'; pl = 'Maks(,)';es_ES = 'Max(,)';es_CO = 'Max(,)';tr = 'Maks (,)';it = 'Max(,)';de = 'Max(,)'"), 2);
	AddOperator(Tree, OperatorsGroup, NStr("ru='Минимум'; en = 'Min'; pl = 'Minimum';es_ES = 'Mínimo';es_CO = 'Mínimo';tr = 'Minimum';it = 'min';de = 'Mindestens'"),     NStr("ru='Мин(,)'; en = 'Min(,)'; pl = 'Min(,)';es_ES = 'Min(,)';es_CO = 'Min(,)';tr = 'Min (,)';it = 'Min(,)';de = 'Min(,)'"),  2);
	AddOperator(Tree, OperatorsGroup, NStr("ru='Округление'; en = 'Rounding'; pl = 'Zaokrąglenie';es_ES = 'Redondeo';es_CO = 'Redondeo';tr = 'Kapalı yuvarlak';it = 'Arrotondamento';de = 'Abrunden'"),  NStr("ru='Окр(,)'; en = 'Round (,)'; pl = 'Zaok(,)';es_ES = 'Round(,)';es_CO = 'Round(,)';tr = 'Yuv (,)';it = 'Arrotonda';de = 'Rundung(,)'"),  2);
	AddOperator(Tree, OperatorsGroup, NStr("ru='Целая часть'; en = 'Integral part'; pl = 'Cała część';es_ES = 'Parte entera';es_CO = 'Parte entera';tr = 'Tamsayı parçası';it = 'Parte intera';de = 'Ganze Position'"), NStr("ru='Цел()'; en = 'Int()'; pl = 'Cał()';es_ES = 'Int()';es_CO = 'Int()';tr = 'Tam()';it = 'Int()';de = 'Ganz()'"),   1);
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("ru='Строковые функции'; en = 'String functions'; pl = 'Funkcje wierszy';es_ES = 'Funciones lineales';es_CO = 'Funciones lineales';tr = 'Satır işlevleri';it = 'Funzioni di stringa';de = 'Zeichenkette-Funktionen'"));
	
	AddOperator(Tree, OperatorsGroup, NStr("ru='Строка'; en = 'Row'; pl = 'Wiersz';es_ES = 'Línea';es_CO = 'Línea';tr = 'Satır';it = 'Riga';de = 'Zeichenkette'"), NStr("ru='Строка()'; en = 'String()'; pl = 'Wiersz()';es_ES = 'String()';es_CO = 'String()';tr = 'Satır()';it = 'Stringa';de = 'Zeichenkette()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='ВРег'; en = 'Upper'; pl = 'Upper';es_ES = 'Upper';es_CO = 'Upper';tr = 'Upper';it = 'Upper';de = 'Upper'"), NStr("ru='ВРег()'; en = 'Upper()'; pl = 'Upper()';es_ES = 'Upper()';es_CO = 'Upper()';tr = 'Upper()';it = 'Upper()';de = 'Upper()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='Лев'; en = 'Left'; pl = 'Lewo';es_ES = 'Izquierda';es_CO = 'Izquierda';tr = 'Sol';it = 'Sinistra';de = 'Links'"), NStr("ru='Лев()'; en = 'Left()'; pl = 'Lew()';es_ES = 'Left()';es_CO = 'Left()';tr = 'Sol()';it = 'Sinistra';de = 'Links()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='НРег'; en = 'Lower'; pl = 'Lower';es_ES = 'Lower';es_CO = 'Lower';tr = 'Lower';it = 'Lower';de = 'Lower'"), NStr("ru='НРег()'; en = 'Lower()'; pl = 'Lower()';es_ES = 'Lower()';es_CO = 'Lower()';tr = 'Lower()';it = 'Lower()';de = 'Lower()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='Прав'; en = 'Rights'; pl = 'Prawa';es_ES = 'Derecha';es_CO = 'Derecha';tr = 'Sağ';it = 'Permessi';de = 'Rechts'"), NStr("ru='Прав()'; en = 'Right()'; pl = 'Praw()';es_ES = 'Right()';es_CO = 'Right()';tr = 'Sağ()';it = 'Right()';de = 'Rechts()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='СокрЛ'; en = 'TrimL'; pl = 'SkrL';es_ES = 'TrimL';es_CO = 'TrimL';tr = 'KısaL';it = 'TrimL';de = 'SokrL'"), NStr("ru='СокрЛ()'; en = 'TrimL()'; pl = 'SkrL()';es_ES = 'TrimL()';es_CO = 'TrimL()';tr = 'KısaL()';it = 'TrimL()';de = 'SokrL()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='СокрЛП'; en = 'TrimAll'; pl = 'SkrLP';es_ES = 'TrimAll';es_CO = 'TrimAll';tr = 'KısaLP';it = 'TrimAll';de = 'SokrLP'"), NStr("ru='СокрЛП()'; en = 'TrimAll()'; pl = 'SkrLP()';es_ES = 'TrimAll()';es_CO = 'TrimAll()';tr = 'KısaLP';it = 'TrimAll()';de = 'SokrLP()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='СокрП'; en = 'TrimR'; pl = 'SkrP';es_ES = 'TrimR';es_CO = 'TrimR';tr = 'KısaP';it = 'TrimR';de = 'SokrP'"), NStr("ru='СокрП()'; en = 'TrimR()'; pl = 'SkrP()';es_ES = 'TrimR()';es_CO = 'TrimR()';tr = 'KısaP()';it = 'TrimR()';de = 'SokrL()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='ТРег'; en = 'Title'; pl = 'Title';es_ES = 'Title';es_CO = 'Title';tr = 'Title';it = 'Title';de = 'Title'"), NStr("ru='ТРег()'; en = 'Title()'; pl = 'Title()';es_ES = 'Title()';es_CO = 'Title()';tr = 'Title()';it = 'Title()';de = 'Title()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='СтрЗаменить'; en = 'StrReplace'; pl = 'StrReplace';es_ES = 'StrReplace';es_CO = 'StrReplace';tr = 'StrReplace';it = 'Sostituisci stringa';de = 'SeiteErsetzen'"), NStr("ru='СтрЗаменить(,,)'; en = 'StrReplace(,,)'; pl = 'StrReplace(,,)';es_ES = 'StrReplace(,,)';es_CO = 'StrReplace(,,)';tr = 'StrReplace(,,)';it = 'StrReplace(,,)';de = 'SeiteErsetzen(,,)'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='СтрДлина'; en = 'StrLen'; pl = 'StrDługość';es_ES = 'StrLen()';es_CO = 'StrLen()';tr = 'StrLen';it = 'Lunghezza stringa';de = 'SeiteLänge'"), NStr("ru='СтрДлина()'; en = 'StrLen()'; pl = 'StrDługość()';es_ES = 'StrLen()';es_CO = 'StrLen()';tr = 'StrLen()';it = 'StrLen()';de = 'SeiteLänge()'"));
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("ru='Прочие функции'; en = 'Other functions'; pl = 'Inne funkcje';es_ES = 'Otras funciones';es_CO = 'Otras funciones';tr = 'Diğer işlevler';it = 'Altre funzioni';de = 'Weitere Funktionen'"));
	
	AddOperator(Tree, OperatorsGroup, NStr("ru='Условие'; en = 'Condition'; pl = 'Warunek';es_ES = 'Condición';es_CO = 'Condición';tr = 'Koşul';it = 'Condizione';de = 'Bedingung'"), "?(,,)", 3);
	AddOperator(Tree, OperatorsGroup, NStr("ru='Предопределенное значение'; en = 'Predefined value'; pl = 'Predefiniowana wartość';es_ES = 'Valor predeterminado';es_CO = 'Valor predeterminado';tr = 'Öntanımlı değer';it = 'Valore predefinito';de = 'Vordefinierter Wert'"), NStr("ru='ПредопределенноеЗначение()'; en = 'PredefinedValue()'; pl = 'PredefinedValue()';es_ES = 'PredefinedValue()';es_CO = 'PredefinedValue()';tr = 'PredefinedValue()';it = 'PredefinedValue()';de = 'VordefinierterWert()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='Значение заполнено'; en = 'Value is filled in'; pl = 'Wartość jest wypełniona';es_ES = 'Valor está rellenado';es_CO = 'Valor está rellenado';tr = 'Değer dolduruldu';it = 'Il valore è compilato';de = 'Wert ist ausgefüllt'"), NStr("ru='ЗначениеЗаполнено()'; en = 'ValueIsFilled()'; pl = 'ValueIsFilled()';es_ES = 'ValueIsFilled)';es_CO = 'ValueIsFilled)';tr = 'ValueIsFilled()';it = 'ValoreCompilato()';de = 'WertAusgefüllt()'"));
	AddOperator(Tree, OperatorsGroup, NStr("ru='Формат'; en = 'Format'; pl = 'Format';es_ES = 'Formato';es_CO = 'Formato';tr = 'Format';it = 'Formato';de = 'Format'"), NStr("ru='Формат(,)'; en = 'Format(,)'; pl = 'Format(,)';es_ES = 'Formato(,)';es_CO = 'Formato(,)';tr = 'Biçim(,)';it = 'Formato(,)';de = 'Format(,)'"));
	
	Return Tree;
	
EndFunction

&AtClientAtServerNoContext
Function GetOperandTextToInsert(Operand)
	
	Return "[" + Operand + "]";
	
EndFunction

&AtClient
Function CheckFormula(Formula, Operands)
	
	If Not ValueIsFilled(Formula) Then
		Return True;
	EndIf;
	
	ReplacementValue = """1""";
	
	CalculationText = Formula;
	For Each Operand In Operands Do
		CalculationText = StrReplace(CalculationText, GetOperandTextToInsert(Operand), ReplacementValue);
	EndDo;
	
	If StrStartsWith(TrimL(CalculationText), "=") Then
		CalculationText = Mid(TrimL(CalculationText), 2);
	EndIf;
	
	Try
		CalculationResult = Eval(CalculationText);
	Except
		ErrorText = NStr("ru = 'В формуле обнаружены ошибки. Проверьте формулу.
			|Формулы должны составляться по правилам написания выражений на встроенном языке 1С:Предприятия.'; 
			|en = 'Errors are detected in the formula. Check the formula.
			|Formulas should be created based on the expression rules of 1C:Enterprise code.'; 
			|pl = 'W formule występują błędy. Sprawdź formułę.
			|Wzory powinny być kompilowane przez zasady pisania wyrażeń w języku 1C: Enterprise.';
			|es_ES = 'En la fórmula se han encontrado errores. Compruebe la fórmula.
			|Las fórmulas deben componerse según las reglas de escribir las expresiones en el lenguaje integrado de 1C:Enterprise.';
			|es_CO = 'En la fórmula se han encontrado errores. Compruebe la fórmula.
			|Las fórmulas deben componerse según las reglas de escribir las expresiones en el lenguaje integrado de 1C:Enterprise.';
			|tr = 'Formülde hatalar bulundu. Formülü kontrol edin.
			|Formüller, yerleşik 1C:İşletme ''de ifade yazma kurallarına göre hazırlanmalıdır.';
			|it = 'Errori sono stati rilevati nella formula. Controllare la formula.
			|Le formule dovrebbero essere create in base alle regole delle espressioni del linguaggio 1C:Enterprise.';
			|de = 'Es gibt Fehler in der Formel. Überprüfen Sie die Formel.
			|Formeln sollten nach den Regeln des Schreibens von Ausdrücken in der integrierten Sprache 1C:Enterprise erstellt werden.'");
		MessageToUser(ErrorText, , "Formula");
		Return False;
	EndTry;
	
	Return True;
	
EndFunction 

&AtClientAtServerNoContext
Function TextFormulaOperands(Formula)
	
	OperandsArray = New Array();
	
	FormulaText = TrimAll(Formula);
	If StrOccurrenceCount(FormulaText, "[") <> StrOccurrenceCount(FormulaText, "]") Then
		OperandsAvailable = False;
	Else
		OperandsAvailable = True;
	EndIf;
	
	While OperandsAvailable = True Do
		OperandStart = StrFind(FormulaText, "[");
		OperandEnd = StrFind(FormulaText, "]");
		
		If OperandStart = 0
			Or OperandEnd = 0
			Or OperandStart > OperandEnd Then
			OperandsAvailable = False;
			Break;
			
		EndIf;
		
		OperandName = Mid(FormulaText, OperandStart + 1, OperandEnd - OperandStart - 1);
		OperandsArray.Add(OperandName);
		FormulaText = StrReplace(FormulaText, "[" + OperandName + "]", "");
		
	EndDo;
	
	Return OperandsArray
	
EndFunction

&AtClient
Procedure CheckFormulaInteractive(Formula, Operands)
	
	If ValueIsFilled(Formula) Then
		If CheckFormula(Formula, Operands) Then
			ShowUserNotification(
				NStr("ru = 'В формуле ошибок не обнаружено'; en = 'Errors were not detected in the formula'; pl = 'Nie znaleziono błędów w formule';es_ES = 'En la fórmula no se han encontrado errores';es_CO = 'En la fórmula no se han encontrado errores';tr = 'Formülde hata bulunamadı';it = 'Nessun errore è stato rilevato nella formula';de = 'In der Formel wurden keine Fehler gefunden'"),
				,
				,
				Information32Picture());
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function Information32Picture()
	If SSLVersionMatchesRequirements() Then
		Return PictureLib["Information32"];
	Else
		Return New Picture;
	EndIf;
EndFunction

&AtServer
Function SSLVersionMatchesRequirements()
	DataProcessorObject = FormAttributeToValue("Object");
	Return DataProcessorObject.SSLVersionMatchesRequirements();
EndFunction

&AtServer
Procedure SetFormItemProperty(FormItems, ItemName, PropertyName, Value)
	
	FormItem = FormItems.Find(ItemName);
	If FormItem <> Undefined AND FormItem[PropertyName] <> Value Then
		FormItem[PropertyName] = Value;
	EndIf;
	
EndProcedure 

&AtClient
Procedure MessageToUser(Val MessageToUserText, Val Field = "", Val DataPath = "")
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Field = Field;
	
	If NOT IsBlankString(DataPath) Then
		Message.DataPath = DataPath;
	EndIf;
		
	Message.Message();
EndProcedure

#EndRegion
