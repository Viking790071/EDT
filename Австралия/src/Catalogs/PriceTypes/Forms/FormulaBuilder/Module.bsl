#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Formula", Formula);
	
	If Parameters.Property("Company") Then 
		Company = Parameters.Company; 
	Else
		Company = DriveReUse.GetUserDefaultCompany();
	EndIf;
	
	OperandBegin = PriceGenerationFormulaServerCall.StringBeginOperand();
	OperandEnd = PriceGenerationFormulaServerCall.StringEndOperand();
	
	FillOperands();
	FillOperatorsTree();
	
EndProcedure

&AtClient

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FormulaOnChange(Item)
	
	OperatorsAllowingComma = New Array;
	OperatorsAllowingComma.Add("MIN");
	OperatorsAllowingComma.Add("MAX");
	OperatorsAllowingComma.Add("ROUND");
	
	ValidCommasCount = 0;
	For Each Item In OperatorsAllowingComma Do
		
		ValidCommasCount = ValidCommasCount + StrOccurrenceCount(Upper(Formula), Upper(Item));
		
	EndDo;
	
	CommasCount = StrOccurrenceCount(Formula, ",");
	If CommasCount > ValidCommasCount Then
		
		TextMessage = NStr("en ='To specify the fractional part, you must use a point, not a comma.'; ru = 'Для указания десятичной части используйте точку, а не запятую.';pl = 'Do podania części dziesiętnej, należy używać kropki, nie przecinka';es_ES = 'Para especificar la parte fraccionaria, debe utilizar un punto, no una coma.';es_CO = 'Para especificar la parte fraccionaria, debe utilizar un punto, no una coma.';tr = 'Kesirli kısmı belirtmek için virgül değil, bir nokta kullanmanız gerekir.';it = 'Per specificare la parte frazionaria è necessario utilizzare un punto al posto della virgola.';de = 'Um den Bruchteil anzugeben, müssen Sie einen Punkt und kein Komma verwenden.'");
		
		CommonClientServer.MessageToUser(TextMessage, , "Formula");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperands

&AtClient
Procedure OperandsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRowData = Items.Operands.CurrentData;
	If CurrentRowData = Undefined Then
		
		Return;
		
	EndIf;
	
	InsertedText = OperandBegin + CurrentRowData.Operand + OperandEnd;
	
	InsertTextToFormula(InsertedText);
	
EndProcedure

&AtClient
Procedure OperandsDragStart(Item, DragParameters, Perform)
	
	FillDragParameters(Item, DragParameters);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperators

&AtClient
Procedure OperatorsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRowData = Items.Operators.CurrentData;
	If CurrentRowData = Undefined Then
		
		Return;
		
	EndIf;
	
	AddingTextParameters = BeforeAddingTextInFormula(CurrentRowData.Operator);
	
	If NOT AddingTextParameters.Cancel Then
		
		InsertTextToFormula(AddingTextParameters.InsertableText, AddingTextParameters.ReplaceFormulaText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OperatorsDragEnd(Item, DragParameters, StandardProcessing)
	
	If DragParameters.Value.Count() < 0 Then
		
		Return;
		
	EndIf;
	
	CurrentRowData = DragParameters.Value[0];
	
	If CurrentRowData = Undefined Then
		
		Return;
		
	EndIf;
	
	StandardProcessing = False;
	
	InsertedText = CurrentRowData.Operator;
	
	If TrimAll(InsertedText) = "%1"
		OR TrimAll(InsertedText) = "%5"
		OR TrimAll(InsertedText) = "%20"
		OR TrimAll(InsertedText) = "%50" Then
		
		OperandData = Items.Operands.CurrentData;
		
		If OperandData = Undefined OR IsBlankString(OperandData.Operand) Then
			
			TextMessage = NStr("en ='Specify the type of prices from which you want to calculate the percentage'; ru = 'Укажите тип цен, на основании которых вы хотите рассчитать процентное соотношение';pl = 'Wybierz rodzaj ceny z tych, które chcesz przeliczyć w procentach';es_ES = 'Especifique el tipo de precios con el que desea calcular el porcentaje.';es_CO = 'Especifique el tipo de precios con el que desea calcular el porcentaje.';tr = 'Yüzdesini hesaplamak istediğiniz fiyat türünü belirtin';it = 'Specifica il tipo di prezzo da cui volete calcolare la percentuale';de = 'Geben Sie den Preistyp an, aus denen Sie den Prozentsatz berechnen möchten.'");
			CommonClientServer.MessageToUser(TextMessage, , "Operands");
			
			Return;
			
		Else
			
			PresentationNumber = StrReplace(InsertedText, "%", "");
			InsertedText = " + ([" + OperandData.Operand + "] / 100 * " + PresentationNumber + ".0)";
			
		EndIf;
		
	EndIf;
	
	InsertTextToFormula(InsertedText);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	AdditionalProcessingFormula();
	
	Close(New Structure("ClosedOK, Formula", True, Formula));
	
EndProcedure

&AtClient
Procedure CheckFormula(Command)
	
	If Not CheckCompany() Then 
		Return;
	EndIf;
	
	Errors = Undefined;
	
	CheckFormulaServer(Errors);
	
	ClearMessages();
	
	If Errors = Undefined Then
		
		TextAlert = NStr("en ='The formula is correct.'; ru = 'Формула правильная.';pl = 'Formuła jest poprawna.';es_ES = 'La fórmula es correcta.';es_CO = 'La fórmula es correcta.';tr = 'Formül doğru.';it = 'La formula è corretta.';de = 'Die Formel ist richtig.'");
		ShowMessageBox(, TextAlert, , NStr("en ='Formula check'; ru = 'Проверка формулы';pl = 'Sprawdzenie formuły';es_ES = 'Compruebe la fórmula';es_CO = 'Compruebe la fórmula';tr = 'Formül kontrolü';it = 'Controllo formula';de = 'Formelüberprüfung'"));
		
	Else
		
		CommonClientServer.ReportErrorsToUser(Errors);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FillDragParameters(Item, DragParameters)
	
	CurrentRowData = Items.Operands.CurrentData;
	DragParameters.Value = OperandBegin + CurrentRowData.Operand + OperandEnd;
	
EndProcedure

&AtServer
Procedure FillOperands()
	
	Query = New Query(
	"SELECT ALLOWED DISTINCT
	|	PriceTypes.OperandID AS Operand,
	|	PRESENTATION(PriceTypes.Ref) AS Presentation,
	|	TRUE AS ThisIsPriceTypeProducts,
	|	0 AS Picture
	|FROM
	|	Catalog.PriceTypes AS PriceTypes
	|WHERE
	|	PriceTypes.PriceCalculationMethod = VALUE(Enum.PriceCalculationMethods.Manual)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SupplierPriceTypes.OperandID,
	|	PRESENTATION(SupplierPriceTypes.Ref),
	|	FALSE,
	|	0
	|FROM
	|	Catalog.SupplierPriceTypes AS SupplierPriceTypes
	|TOTALS
	|	CASE
	|		WHEN ThisIsPriceTypeProducts
	|			THEN &ProductPricesTitle
	|		ELSE &CounterpartiesPricesTitle
	|	END AS Presentation,
	|	1 AS Picture
	|BY
	|	ThisIsPriceTypeProducts");
	
	ProductPricesTitle = NStr("en = 'PRODUCT PRICES'; ru = 'ЦЕНЫ НОМЕНЛАТУРЫ';pl = 'CENY PRODUKTU';es_ES = 'PRECIOS DEL PRODUCTO';es_CO = 'PRECIOS DEL PRODUCTO';tr = 'ÜRÜN FİYATLARI';it = 'PREZZI ARTICOLO';de = 'PRODUKTPREISE'");
	CounterpartiesPricesTitle = NStr("en = 'COUNTERPARTIES PRICES'; ru = 'ЦЕНЫ КОНТРАГЕНТОВ';pl = 'CENY KONTRAHENTÓW';es_ES = 'PRECIOS DE LAS CONTRAPARTIDAS';es_CO = 'PRECIOS DE LAS CONTRAPARTIDAS';tr = 'CARI HESAP FİYATLARI';it = 'PREZZI CONTROPARTI';de = 'GESCHÄFTSPARTNERPREISE'");
	
	Query.SetParameter("ProductPricesTitle", ProductPricesTitle);
	Query.SetParameter("CounterpartiesPricesTitle", CounterpartiesPricesTitle);
	
	ResultTree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	ValueToFormAttribute(ResultTree, "Operands");
	
EndProcedure

&AtClient
Function BeforeAddingTextInFormula(Val InsertableText)
	
	AddingTextParameters = New Structure("InsertableText, ReplaceFormulaText, Cancel", InsertableText, False, False);
	
	OperandData = Items.Operands.CurrentData;
	
	If TrimAll(InsertableText) = "%1"
		OR TrimAll(InsertableText) = "%5"
		OR TrimAll(InsertableText) = "%20"
		OR TrimAll(InsertableText) = "%50" Then
		
		If OperandData = Undefined OR IsBlankString(OperandData.Operand) Then
			
			TextMessage = NStr("en ='Specify the type of prices from which you want to calculate the percentage'; ru = 'Укажите тип цен, на основании которых вы хотите рассчитать процентное соотношение';pl = 'Wybierz rodzaj ceny z tych, które chcesz przeliczyć w procentach';es_ES = 'Especifique el tipo de precios con el que desea calcular el porcentaje.';es_CO = 'Especifique el tipo de precios con el que desea calcular el porcentaje.';tr = 'Yüzdesini hesaplamak istediğiniz fiyat türünü belirtin';it = 'Specifica il tipo di prezzo da cui volete calcolare la percentuale';de = 'Geben Sie die Preistypen an, aus denen Sie den Prozentsatz berechnen möchten.'");
			CommonClientServer.MessageToUser(TextMessage, , "Operands");
			
			AddingTextParameters.Cancel = True;
			
			Return AddingTextParameters;
			
		Else
			
			PresentationNumber = StrReplace(InsertableText, "%", "");
			AddingTextParameters.InsertableText = StrTemplate(" + (%1", OperandBegin)
				+ OperandData.Operand
				+ StrTemplate("%1 / 100 * ", OperandEnd)
				+ PresentationNumber
				+ ".0)";
			
		EndIf;
		
	EndIf;
	
	If TrimAll(AddingTextParameters.InsertableText) = "If" Then
		
		ConditionalOperatorFirstValue = "<?>";
		If NOT IsBlankString(Formula) Then
			
			ConditionalOperatorFirstValue = Formula;
			Formula = "";
			AddingTextParameters.ReplaceFormulaText = True;
			
		ElsIf OperandData <> Undefined AND NOT IsBlankString(OperandData.Operand) Then
			
			ConditionalOperatorFirstValue = OperandBegin + OperandData.Operand + OperandEnd;
			
		EndIf;
		
		AddingTextParameters.InsertableText = StrTemplate("#IF <Condition>%1%2#THEN %3%1%2#ELSE <?>%1#ENDIF",
			Chars.LF,
			Chars.Tab,
			ConditionalOperatorFirstValue);
		
	EndIf;
	
	Return AddingTextParameters;
	
EndFunction

&AtClient
Procedure InsertTextToFormula(InsertableText, ReplaceFormulaText = False)
	
	If IsBlankString(InsertableText) Then
		
		Return;
		
	EndIf;
	
	If ReplaceFormulaText Then
		
		Formula = InsertableText;
		Return;
		
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		Formula = Formula + InsertableText;
		
	Else
		
		RowBegin = 0;
		RowEnd = 0;
		ColumnBegin = 0;
		ColumnEnd = 0;
		
		Items.Formula.GetTextSelectionBounds(RowBegin, ColumnBegin, RowEnd, ColumnEnd);
		If (ColumnEnd = ColumnBegin) AND (ColumnEnd + StrLen(InsertableText)) > Items.Formula.Width / 8 Then
			
			Items.Formula.SelectedText = "";
			
		EndIf;
		
		Items.Formula.SelectedText = InsertableText;
		
	EndIf;
	
	CurrentItem = Items.Formula;
	
EndProcedure

&AtServer
Procedure FillOperatorsTree()
	
	OperatorsTree = FormAttributeToValue("Operators", Type("ValueTree"));
	
	RowsGroup 				= OperatorsTree.Rows.Add();
	RowsGroup.Description	= NStr("en ='ARITHMETIC OPERATORS'; ru = 'АРИФМЕТИЧЕСКИЕ ОПЕРАТОРЫ';pl = 'OPERATORY ARYTMETYCZNE';es_ES = 'OPERADORES ARITMÉTICOS';es_CO = 'OPERADORES ARITMÉTICOS';tr = 'ARİTMETİK OPERATÖRLER';it = 'OPERATORI ARITMETICI';de = 'ARITHMETISCHE OPERATOREN'");
	RowsGroup.Picture		= 1;
	
	NewRow	 				= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Addition'; ru = 'Сложение';pl = 'Dodatek';es_ES = 'Adición';es_CO = 'Adición';tr = 'Toplama';it = 'Addizione';de = 'Zusatz'") + " ""+""";
	NewRow.Operator			= " + ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Subtraction'; ru = 'Вычитание';pl = 'Odejmowanie';es_ES = 'Sustracción';es_CO = 'Sustracción';tr = 'Çıkarma';it = 'Sottrazione';de = 'Subtraktion'") + " ""-""";
	NewRow.Operator			= " - ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Multiplication'; ru = 'Умножение';pl = 'Przemnożenie';es_ES = 'Multiplicación';es_CO = 'Multiplicación';tr = 'Çarpma işlemi';it = 'Moltiplicazione';de = 'Multiplikation'") + " ""*""";
	NewRow.Operator			= " * ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Division'; ru = 'Деление';pl = 'Dzielenie';es_ES = 'División';es_CO = 'División';tr = 'Bölme';it = 'Divisione';de = 'Aufteilung'") + " ""/""";
	NewRow.Operator			= " / ";
	
	RowsGroup 				= OperatorsTree.Rows.Add();
	RowsGroup.Description	= NStr("en ='LOGICAL OPERATORS'; ru = 'ЛОГИЧЕСКИЕ ОПЕРАТОРЫ';pl = 'OPERATORY LOGICZNE';es_ES = 'OPERADORES LÓGICOS';es_CO = 'OPERADORES LÓGICOS';tr = 'MANTIKSAL OPERATÖRLER';it = 'OPERATORI LOGICI';de = 'LOGISCHE OPERATOREN'");
	RowsGroup.Picture		= 1;
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='If...Else...EndIf'; ru = 'Если...Иначе...КонецЕсли';pl = 'If...Else...EndIf';es_ES = 'Si...Más...EndIf';es_CO = 'Si...Más...EndIf';tr = 'İse...Değilse...İseSonlandır';it = 'If...Else...Endif';de = 'If...Else...EndIf'");
	NewRow.Operator			= "If"; 
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= " > ";
	NewRow.Operator			= " > ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= " >= ";
	NewRow.Operator			= " >= ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= " < ";
	NewRow.Operator			= " < ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= " <= ";
	NewRow.Operator			= " <= ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= " = ";
	NewRow.Operator			= " = ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= " <> ";
	NewRow.Operator			= " <> ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='AND'; ru = 'И';pl = 'AND';es_ES = 'Y';es_CO = 'Y';tr = 'VE';it = 'AND';de = 'UND'");
	NewRow.Operator			= " AND ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='OR'; ru = 'ИЛИ';pl = 'OR';es_ES = 'O';es_CO = 'O';tr = 'VEYA';it = 'OR';de = 'ODER'");
	NewRow.Operator			= " OR ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='NOT'; ru = 'НЕ';pl = 'NOT';es_ES = 'NO';es_CO = 'NO';tr = 'DEĞİL';it = 'NOT';de = 'NICHT'");
	NewRow.Operator			= " NOT ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='TRUE'; ru = 'ИСТИНА';pl = 'TRUE';es_ES = 'VERDADERO';es_CO = 'VERDADERO';tr = 'TRUE';it = 'TRUE';de = 'WAHR'");
	NewRow.Operator			= " TRUE ";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='FALSE'; ru = 'ЛОЖЬ';pl = 'FALSE';es_ES = 'FALSO';es_CO = 'FALSO';tr = 'FALSE';it = 'FALSE';de = 'FALSE'");
	NewRow.Operator			= " FALSE ";
	
	NewRow		 			= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Opening bracket'; ru = 'Открывающая скобка';pl = 'Nawias otwierający';es_ES = 'Paréntesis de apertura';es_CO = 'Paréntesis de apertura';tr = 'Açılış parantezi';it = 'Apertura parentesi';de = 'Öffnende Klammer'") + " ""(""";
	NewRow.Operator			= " (";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Closing bracket'; ru = 'Закрывающая скобка';pl = 'Nawias zamykający';es_ES = 'Paréntesis de cierre';es_CO = 'Paréntesis de cierre';tr = 'Kapanış parantezi';it = 'Chiusura parentesi';de = 'Schließende Klammer'") + " "")""";
	NewRow.Operator			= ") ";
	
	RowsGroup 				= OperatorsTree.Rows.Add();
	RowsGroup.Description	= NStr("en ='FUNCTIONS'; ru = 'ФУНКЦИИ';pl = 'FUNKCJE';es_ES = 'FUNCIONES';es_CO = 'FUNCIONES';tr = 'İŞLEVLER';it = 'FUNZIONI';de = 'FUNKTIONEN'");
	RowsGroup.Picture		= 1;
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Maximum'; ru = 'Максимум';pl = 'Maksimum';es_ES = 'Máximo';es_CO = 'Máximo';tr = 'Maksimum';it = 'Massimo';de = 'Maximum'");
	NewRow.Operator			= " MAX(<?>,<?>)";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Minimum'; ru = 'Минимум';pl = 'Minimum';es_ES = 'Mínimo';es_CO = 'Mínimo';tr = 'Minimum';it = 'Minimo';de = 'Minimum'");
	NewRow.Operator			= " MIN(<?>,<?>)";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Whole part'; ru = 'Целая часть числа';pl = 'Cała część';es_ES = 'Parte entera';es_CO = 'Parte entera';tr = 'Tamamı';it = 'Parte intera';de = 'Gesamtteil'");
	NewRow.Operator			= " Int(<?>)";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Round'; ru = 'Округление';pl = 'Zaokrąglenie';es_ES = 'Redondeado';es_CO = 'Redondeado';tr = 'Yuvarlak';it = 'Arrotonda';de = 'Rund'");
	NewRow.Operator			= " Round(<?>,<Precision?>)";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Predefined value'; ru = 'Предопределенное значение';pl = 'Predefiniowana wartość';es_ES = 'Valor predeterminado';es_CO = 'Valor predeterminado';tr = 'Öntanımlı değer';it = 'Valore predefinito';de = 'Vordefinierter Wert'");
	NewRow.Operator			= " PredefinedValue(<?>)";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Value is filled'; ru = 'Значение заполнено';pl = 'Wartość jest wypełniona';es_ES = 'Valor está rellenado';es_CO = 'Valor está rellenado';tr = 'Değer dolduruldu';it = 'Valore compilato';de = 'Wert ist ausgefüllt'");
	NewRow.Operator			= " ValueIsFilled(<?>)";
	
	RowsGroup 				= OperatorsTree.Rows.Add();
	RowsGroup.Description	= NStr("en ='TEMPLATE'; ru = 'МАКЕТ';pl = 'SZABLON';es_ES = 'MODELO';es_CO = 'MODELO';tr = 'Şablon';it = 'MODELLO';de = 'VORLAGE'");
	RowsGroup.Picture		= 1;
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Percent'; ru = 'Процент';pl = 'Procent';es_ES = 'Por ciento';es_CO = 'Por ciento';tr = 'Yüzde';it = 'Percentuale';de = 'Prozent'") + " ""1%""";
	NewRow.Operator			= " %1";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Percent'; ru = 'Процент';pl = 'Procent';es_ES = 'Por ciento';es_CO = 'Por ciento';tr = 'Yüzde';it = 'Percentuale';de = 'Prozent'") + " ""5%""";
	NewRow.Operator			= " %5";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Percent'; ru = 'Процент';pl = 'Procent';es_ES = 'Por ciento';es_CO = 'Por ciento';tr = 'Yüzde';it = 'Percentuale';de = 'Prozent'") + " ""20%""";
	NewRow.Operator			= " %20";
	
	NewRow 					= RowsGroup.Rows.Add();
	NewRow.Description		= NStr("en ='Percent'; ru = 'Процент';pl = 'Procent';es_ES = 'Por ciento';es_CO = 'Por ciento';tr = 'Yüzde';it = 'Percentuale';de = 'Prozent'") + " ""50%""";
	NewRow.Operator			= " %50";
	
	ValueToFormAttribute(OperatorsTree, "Operators");
	
EndProcedure

&AtServer
Procedure CheckFormulaServer(Errors)
	
	PriceGenerationFormulaServerCall.CheckFormula(Errors, Formula, Company);
	
EndProcedure

&AtServer
Procedure AddMultiplicationToFormula()
	
	// The procedure replaces "][" on "]*["
	InsertTable = New ValueTable;
	InsertTable.Columns.Add("OperandPositionBegin");
	InsertTable.Columns.Add("OperandPositionEnd");
	
	OperandPositionBegin = 0;
	OperandPositionEnd = 0;
	
	StringBetween	= "";
	StringLen		= StrLen(Formula);
	
	For CharIndex = 0 To StringLen Do
		
		Char = Mid(Formula, CharIndex, 1);
		If Char = OperandEnd Then
			
			StringBetween			= "";
			OperandPositionEnd		= CharIndex;
			OperandPositionBegin	= 0;
			
		ElsIf Char = OperandBegin Then
			
			OperandPositionBegin = CharIndex;
			
		EndIf;
		
		If OperandPositionEnd <> 0 AND OperandPositionBegin = 0 AND Char <> OperandEnd Then
			
			StringBetween = StringBetween + Char;
			
		ElsIf OperandPositionEnd <> 0 AND OperandPositionBegin <> 0 Then
			
			If IsBlankString(TrimAll(StringBetween)) Then
				
				NewRow						= InsertTable.Add();
				NewRow.OperandPositionBegin	= OperandPositionBegin;
				NewRow.OperandPositionEnd	= OperandPositionEnd;
				
			EndIf;
			
			StringBetween			= "";
			OperandPositionBegin	= 0;
			OperandPositionEnd		= 0;
			
		EndIf;
		
	EndDo;
	
	InsertCount = InsertTable.Count();
	If InsertCount > 0 Then
		
		While InsertCount <> 0 Do
			
			RowTable = InsertTable.Get(InsertCount - 1);
			
			FirstSubstring	= Left(Formula, RowTable.OperandPositionEnd);
			SecondSubstring	= Mid(Formula, RowTable.OperandPositionBegin);
			Formula 		= FirstSubstring + " * " + SecondSubstring;
			
			InsertCount = InsertCount - 1;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalProcessingFormula()
	
	AddMultiplicationToFormula();
	
EndProcedure

&AtClient
Function CheckCompany()
	
	If Not ValueIsFilled(Company) Then
		CommonClientServer.MessageToUser(
			NStr("en = 'The company must be filled.'; ru = 'Поле ""Организация"" не может быть пустым.';pl = 'Firma powinna być wypełniona.';es_ES = 'La empresa debe estar rellenada.';es_CO = 'La empresa debe estar rellenada.';tr = 'İş yeri mutlaka doldurulmalıdır.';it = 'L''azienda deve essere compilata.';de = 'Die Firma soll ausgefüllt sein.'"), , 
			"Company");
		Return False;
	Else
		Return True;
	EndIf
	
EndFunction

#EndRegion