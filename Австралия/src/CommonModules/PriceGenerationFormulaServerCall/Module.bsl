#Region Public

#Region ConstantValues

Function StringEndOperand() Export
	
	Return "]";
	
EndFunction

Function StringBeginOperand() Export
	
	Return "[";
	
EndFunction

#EndRegion

#Region Formulas

Function GetOperandsFormulaTable(Period, CalculateParameters) Export
	
	FormulaStore = CalculateParameters.Formula;
	
	Operands = New ValueTable;
	Operands.Columns.Add("Operand");
	Operands.Columns.Add("PriceType");
	Operands.Columns.Add("PriceTypeExchangeRate");
	Operands.Columns.Add("PriceTypeMultiplicity");
	Operands.Columns.Add("ThisIsProductsPrice");
	
	Operands.Indexes.Add("Operand");
	
	If TypeOf(FormulaStore) = Type("String") Then
		
		ParsingFormulaForOperands(Period, FormulaStore, Operands, CalculateParameters.Company);
		
	ElsIf TypeOf(FormulaStore) = Type("Array") Then
		
		For Each ArrayItem In FormulaStore Do
			
			ParsingFormulaForOperands(Period, ArrayItem, Operands, CalculateParameters.Company);
			
		EndDo;
		
	EndIf;
	
	Return Operands;
	
EndFunction

Function FindPriceTypeByID(ID) Export
	
	Result = New Structure("PriceType, ThisIsProductsPrice", Undefined, Undefined);
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	PriceTypes.Ref AS PriceType,
	|	TRUE AS ThisIsProductsPrice
	|FROM
	|	Catalog.PriceTypes AS PriceTypes
	|WHERE
	|	PriceTypes.OperandID = &ID
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	SupplierPriceTypes.Ref,
	|	FALSE
	|FROM
	|	Catalog.SupplierPriceTypes AS SupplierPriceTypes
	|WHERE
	|	SupplierPriceTypes.OperandID = &ID";
	
	Query.SetParameter("ID", ID);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		FillPropertyValues(Result, Selection);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function CheckPriceTypeID(ID, ExcludeRef = Undefined) Export
	
	Result = True;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	PriceTypes.Ref AS Ref
	|FROM
	|	Catalog.PriceTypes AS PriceTypes
	|WHERE
	|	PriceTypes.OperandID = &ID
	|	AND PriceTypes.Ref <> &Ref
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	SupplierPriceTypes.Ref
	|FROM
	|	Catalog.SupplierPriceTypes AS SupplierPriceTypes
	|WHERE
	|	SupplierPriceTypes.OperandID = &ID
	|	AND SupplierPriceTypes.Ref <> &Ref";
	
	Query.SetParameter("ID", ID);
	Query.SetParameter("Ref", ExcludeRef);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		Result = False;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure GenerateNewIndicatorPriceType(ID, PriceTypeDescription, PriceTypeOwner = "") Export
	
	If IsBlankString(PriceTypeDescription) Then
		
		Return;
		
	EndIf;
	
	ID = String(PriceTypeOwner) + String(PriceTypeDescription);
	ID = Title(ID);
	
	StringLen = StrLen(ID);
	While StringLen > 0 Do
		
		CharCode = CharCode(ID, StringLen);
		
		If NOT ((CharCode >= 48 AND CharCode <= 57)				// Numbers 
			OR (CharCode >= 65  AND CharCode <= 90)				// Latin caps
			OR (CharCode >= 97  AND CharCode <= 122)			// Latin uppercase
			OR (CharCode >= 1040 AND CharCode <= 1103)) Then	// Cyrillic
			
			ID = Mid(ID, 1, StringLen - 1) + Mid(ID, StringLen + 1);
			
		EndIf;
		
		StringLen = StringLen - 1;
		
	EndDo;
	
	If IsBlankString(ID) Then
		
		ID = "IDPriceType";
		
	EndIf;
	
	// the first character must be a letter
	CharCode = CharCode(ID, 1);
	If CharCode >= 48 And CharCode <= 57 Then
		
		ID = "a" + ID;
		
	EndIf;
	
	PostFix = 0;
	IDBody = ID;
	While NOT CheckPriceTypeID(ID) Do
		
		PostFix = PostFix + 1;
		ID = IDBody + String(PostFix);
		
	EndDo;
	
EndProcedure

Procedure CheckFormula(Errors, Formula, Company) Export
	
	MapOperands = Undefined;
	CalculatedData = Undefined;
	ValueAllOperands = 10; // When checking the formula, the values of all operands are assumed to be 10
	
	FormulaText = TrimAll(Formula);
	
	If StrOccurrenceCount(FormulaText, StringBeginOperand()) <> StrOccurrenceCount(FormulaText, StringEndOperand()) Then
		
		ErrorText = NStr("en ='The number of open operands is not equal to the number of closed.'; ru = 'Количество открытых операндов не соответствует количеству закрытых операндов.';pl = 'Ilość otwartych operandów nie odpowiada ilości zamkniętych.';es_ES = 'El número de operandos abiertos no es igual al número de operandos cerrados.';es_CO = 'El número de operandos abiertos no es igual al número de operandos cerrados.';tr = 'Açık işlenenlerin sayısı kapalı olanların sayısına eşit değil.';it = 'Il numero di operandi aperti non è uguale al numero di quelli chiusi.';de = 'Die Anzahl der offenen Operanden ist nicht gleich der Anzahl der geschlossenen Operanden.'");
		CommonClientServer.AddUserError(Errors, "Formula", ErrorText, "");
		
	EndIf;
	
	If StrOccurrenceCount(FormulaText, "(") <> StrOccurrenceCount(FormulaText, ")") Then
		
		ErrorText = NStr("en ='The number of open brackets is not equal to the number of closed ones.'; ru = 'Количество открытых скобок не соответствует количеству закрытых.';pl = 'Ilość otwartych nawiasów nie odpowiada ilości zamkniętych.';es_ES = 'El número de paréntesis abiertos no es igual al número de paréntesis cerrados.';es_CO = 'El número de paréntesis abiertos no es igual al número de paréntesis cerrados.';tr = 'Açık parantezlerin sayısı kapalı olanların sayısına eşit değil.';it = 'Il numero di parentesi aperte è diverso da quello di quelle chiuse.';de = 'Die Anzahl der offenen Klammern ist nicht gleich der Anzahl der geschlossenen Klammern.'");
		CommonClientServer.AddUserError(Errors, "Formula", ErrorText, "");
		
	EndIf;
	
	CalculateParameters = New Structure("Formula, Company", Formula, Company);
	OperandsTable = GetOperandsFormulaTable(CurrentSessionDate(), CalculateParameters);
	For Each Row In OperandsTable Do
		
		If NOT ValueIsFilled(Row.PriceType) Then
			
			ErrorText = NStr("en ='Operand not recognized %1.
				|Check the spelling of the formula.'; 
				|ru = 'Операнд не опознан %1.
				|Проверьте написание формулы.';
				|pl = 'Nie rozpoznano operand %1.
				|Sprawdź prawidłowość formuły.';
				|es_ES = 'Operando no reconocido %1. 
				|Revise la ortografía de la fórmula.';
				|es_CO = 'Operando no reconocido %1. 
				|Revise la ortografía de la fórmula.';
				|tr = '%1işleneni tanınmadı. 
				|Formülün yazılışını kontrol edin.';
				|it = 'Operando non riconosciuto %1.
				|Controllare la formula.';
				|de = 'Operand nicht erkannt %1.
				|Überprüfen Sie die Schreibweise der Formel.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, Row.Operand);
			
			CommonClientServer.AddUserError(Errors, "Formula", ErrorText, "");
			
		EndIf;
		
		AddOperandToStructure(MapOperands, Row.Operand, ValueAllOperands);
		
	EndDo;
	
	CalculateDataByFormula(FormulaText, MapOperands, CalculatedData);
	
	If CalculatedData.ErrorCalculation Then
		
		ErrorText = NStr("en = 'There were errors in the calculation. Check the spelling of the formula.
			|Detailed description: %1'; 
			|ru = 'При расчете возникли ошибки. Проверьте написание формулы.
			|Подробное описание: %1';
			|pl = 'W obliczeniu byli błędy. Sprawdź prawidłowość formuły.
			|Szczególny opis: %1';
			|es_ES = 'Se han producido errores en el cálculo. Revise la ortografía de la fórmula.
			| Descripción detallada: %1';
			|es_CO = 'Se han producido errores en el cálculo. Revise la ortografía de la fórmula.
			| Descripción detallada: %1';
			|tr = 'Hesaplamada hatalar oluştu. Formülün yazılışını kontrol edin.
			|Ayrıntılı açıklama: %1';
			|it = 'Sono stati rilevati errori di calcolo. Verificare la formula.
			|Dettagli: %1';
			|de = 'Bei der Berechnung sind Fehler aufgetreten. Überprüfen Sie die Schreibweise der Formel.
			|Detaillierte Beschreibung: %1'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, CalculatedData.ErrorText);
		
		CommonClientServer.AddUserError(Errors, "Formula", ErrorText, "");
		
	EndIf;
	
EndProcedure

Procedure AddOperandToStructure(MapOperands, Operand, Value) Export
	
	If TypeOf(MapOperands) <> Type("Map") Then
		MapOperands = New Map;
	EndIf;
	
	MapOperands.Insert(Operand, Value);
	
EndProcedure

Procedure PrepareDataStringsCollections(OperandsMap, StringCollection, OperandsTable, CalculatedData) Export
	
	For Each OperandRow In OperandsTable Do
		
		Value			= 0;
		ExchangeRate	= 1;
		Multiplicity	= 1;
		NewExchangeRate	= 1;
		NewMultiplicity	= 1;
		
		If OperandRow.ThisIsProductsPrice <> Undefined Then
			
			OperandID			= OperandRow.PriceType.OperandID;
			Value				= StringCollection["Value_" + OperandID];
			ExchangeRate		= StringCollection["ExchangeRate_" + OperandID];
			Multiplicity		= StringCollection["Multiplicity_" + OperandID];
			NewExchangeRate		= CalculatedData.ExchangeRate;
			NewMultiplicity		= CalculatedData.Multiplicity;
			MeasurementUnitKey	= "MeasurementUnit_" + OperandID;
			MeasurementUnit		= StringCollection[MeasurementUnitKey];
			
		Else
			
			Value				= OperandRow.Value;
			MeasurementUnitKey	= "MeasurementUnit_Base";
			MeasurementUnit		= StringCollection.Products.MeasurementUnit;
			
		EndIf;
		
		If ValueIsFilled(Value) Then
		
			FormatValue			= "ND=15; NFD=3; NDS=.; NG=0";
			FormatExchangeRate	= "ND=15; NFD=4; NDS=.; NG=0";
			
			If Number(ExchangeRate) = Number(NewExchangeRate) AND Number(Multiplicity) = Number(NewMultiplicity) Then
				
				Value = Format(Number(Value), FormatValue);
				
			Else
				
				TemplateCalculateValue = "((%1 * %2 * %3) / (%4 * %5))";
				
				Value = StrTemplate(TemplateCalculateValue,
					Format(Number(Value), 			FormatValue),
					Format(Number(ExchangeRate),	FormatExchangeRate),
					Format(Number(NewMultiplicity),	FormatExchangeRate),
					Format(Number(NewExchangeRate),	FormatExchangeRate),
					Format(Number(Multiplicity),	FormatExchangeRate));
				
			EndIf;
		
		Else
			
			Value = 0;
			
		EndIf;
		
		If ValueIsFilled(MeasurementUnit) Then
			
			OperandsMap.Insert(MeasurementUnitKey, MeasurementUnit);
			
			If NOT ValueIsFilled(StringCollection.MeasurementUnit) Then
				
				StringCollection.MeasurementUnit = MeasurementUnit;
				
			EndIf;
			
			If StringCollection.MeasurementUnit <> MeasurementUnit Then
				
				Value = "(" + Value + " * " + PriceGenerationServer.RecalculationMeasurementUnits(MeasurementUnit, StringCollection.MeasurementUnit, True) + ")";
				
			EndIf;
			
		EndIf;
		
		OperandsMap.Insert(OperandRow.Operand, Value);
		
	EndDo;
	
EndProcedure

Procedure CalculateDataByFormula(Val FormulaText, OperandsStructure, CalculatedData = Undefined) Export
	
	If CalculatedData = Undefined Then
		CalculatedData = New Structure("Price, MeasurementUnit, ErrorCalculation, ErrorText", 0, Undefined, False);
	EndIf;
	
	If OperandsStructure = Undefined Then
		Return;
	EndIf;
	
	If Find(FormulaText, "#IF") > 0 Then
		FormulaText = StrReplace(FormulaText, "#IF",	"?(");
		FormulaText = StrReplace(FormulaText, "#THEN",	",");
		FormulaText = StrReplace(FormulaText, "#ELSE",	",");
		FormulaText = StrReplace(FormulaText, "#ENDIF",	")");
		FormulaText = StrReplace(FormulaText, Chars.LF,	"");
	EndIf;
	
	For Each Operand In OperandsStructure Do
		FormulaText = StrReplace(FormulaText, Operand.Key, Operand.Value);
	EndDo;
	
	Try
		
		CalculatedPrice = Common.CalculateInSafeMode(FormulaText);
		
		If ValueIsFilled(CalculatedPrice) Then
			CalculatedData.Price = DriveClientServer.RoundPrice(CalculatedPrice, Enums.RoundingMethods.Round0_01);
		Else
			CalculatedData.Price = 0;
		EndIf;
		
		If NOT ValueIsFilled(CalculatedData.MeasurementUnit) Then
			
			CalculateMeasurementUnit = Undefined;
			For Each Operand In OperandsStructure Do
				
				If Find(Operand.Key, "MeasurementUnit") > 0 Then
					
					CalculateMeasurementUnit = Operand.Value;
					If TypeOf(CalculateMeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
						
						Break;
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
			CalculatedData.MeasurementUnit = CalculateMeasurementUnit;
			
		EndIf;
		
	Except
		
		CalculatedData.ErrorCalculation	= True;
		CalculatedData.ErrorText		= DetailErrorDescription(ErrorInfo());
		
	EndTry;
	
EndProcedure

Procedure CalculateDataCollection(
	ProductsCollection,
	OperandsTable,
	CalculateParameters,
	UseCurrentValue = False,
	ThisIsCollectionWithIndexes = False) Export
	
	AuthorizedUser = Users.AuthorizedUser();
	
	OperandsMap = New Map;
	
	TransposeTablesCollectionsAndOperands(ProductsCollection,
		OperandsTable,
		OperandsMap,
		UseCurrentValue,
		ThisIsCollectionWithIndexes);
	
	CountRecords = ProductsCollection.Count();
	UseAutor = (ProductsCollection.Columns.Find("Autor") <> Undefined);
	CalculatedData = New Structure("Price, ExchangeRate, Multiplicity, MeasurementUnit, ErrorCalculation, ErrorText");
	
	While CountRecords > 0 Do
		
		RowCollection = ProductsCollection.Get(CountRecords - 1);
		CountRecords = CountRecords - 1;
		
		If IsBlankString(RowCollection.Formula) Then
			
			Continue;
			
		EndIf;
		
		If UseAutor AND NOT ValueIsFilled(RowCollection.Autor) Then
			
			RowCollection.Autor = AuthorizedUser;
			
		EndIf;
		
		If RowCollection.Price = 0 Then
			
			OperandsMap.Clear();
			
			CalculatedData.Price			= 0;
			CalculatedData.ExchangeRate		= CalculateParameters.ExchangeRate;
			CalculatedData.Multiplicity		= CalculateParameters.Multiplicity;
			CalculatedData.MeasurementUnit	= RowCollection.MeasurementUnit;
			CalculatedData.ErrorCalculation	= False;
			CalculatedData.ErrorText		= Undefined;
			
			PrepareDataStringsCollections(OperandsMap, RowCollection, OperandsTable, CalculatedData);
			
			CalculateDataByFormula(RowCollection.Formula, OperandsMap, CalculatedData);
			
			RowCollection.Price = CalculatedData.Price;
			
			If NOT ValueIsFilled(RowCollection.MeasurementUnit) Then
				
				RowCollection.MeasurementUnit = CalculatedData.MeasurementUnit;
				
			ElsIf ValueIsFilled(CalculatedData.MeasurementUnit)
				AND RowCollection.MeasurementUnit <> CalculatedData.MeasurementUnit Then
				
				If TypeOf(CalculatedData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					
					RowCollection.Price = RowCollection.Price / CalculatedData.MeasurementUnit.Factor;
					
				ElsIf TypeOf(RowCollection.MeasurementUnit) = Type("CatalogRef.UOM") Then
					
					RowCollection.Price = RowCollection.Price * RowCollection.MeasurementUnit.Factor;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If NOT ThisIsCollectionWithIndexes AND NOT ValueIsFilled(RowCollection.Price) Then
			
			ProductsCollection.Delete(RowCollection);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetPriceByFormula(ParametersStructure) Export
	
	FormTableProducts = New ValueTable;
	FormTableProducts.Columns.Add("Check", New TypeDescription("Boolean"));
	FormTableProducts.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	FormTableProducts.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsCharacteristics"));
	FormTableProducts.Columns.Add("Price", New TypeDescription("Number"));
	FormTableProducts.Columns.Add("MeasurementUnit");
	FormTableProducts.Columns.Add("Picture", New TypeDescription("Number"));
	FormTableProducts.Columns.Add("OriginalPrice", New TypeDescription("Number"));
	FormTableProducts.Columns.Add("KeyConnection", New TypeDescription("Number"));
	
	FormTableCharacteristics = FormTableProducts.Copy();
	
	If ValueIsFilled(ParametersStructure.Characteristic) Then
		NewRow = FormTableCharacteristics.Add();
		NewRow.Characteristic = ParametersStructure.Characteristic;
	Else
		NewRow = FormTableProducts.Add();
		NewRow.Characteristic = Catalogs.ProductsCharacteristics.EmptyRef();
	EndIf;
	
	NewRow.Check = True;
	NewRow.Products = ParametersStructure.Products;
	NewRow.MeasurementUnit = ParametersStructure.MeasurementUnit;
	NewRow.KeyConnection = 1;
	
	FormDataCollections = New Structure("FormTableProducts, FormTableCharacteristics", FormTableProducts, FormTableCharacteristics);
	
	PriceFormationParameters = New Structure;
	PriceFormationParameters.Insert("Formula", ParametersStructure.PriceKind.Formula);
	PriceFormationParameters.Insert("PriceTypesToRecalculate", Undefined);
	PriceFormationParameters.Insert("ShowCharacteristic", True);
	PriceFormationParameters.Insert("SetCharacteristicsWithoutPrice", True);
	PriceFormationParameters.Insert("FormDataCollections", FormDataCollections);
	PriceFormationParameters.Insert("Company", ParametersStructure.Company);
	
	PriceTypesToRecalculate = New Map;
	PriceTypesToRecalculate.Insert(ParametersStructure.PriceKind, ParametersStructure.PriceKind);
	PriceFormationParameters.PriceTypesToRecalculate = PriceTypesToRecalculate;
	
	CalculateNewPricesByFormula(PriceFormationParameters);
	
	For Each TempTable In PriceFormationParameters.FormDataCollections Do
		For Each RowTable In TempTable.Value Do
			Return RowTable.Price;
		EndDo;
	EndDo;
	
EndFunction

Function GetTabularSectionPricesByFormula(ParametersStructure, DocumentTabularSection) Export
	
	DocumentTabularSection.Columns.Add("PriceIncludesVAT", New TypeDescription("Boolean"));
	DocumentTabularSection.Columns.Add("Price", New TypeDescription("Number"));
	
	FormTableProducts = DocumentTabularSection.Copy();
	
	FormTableProducts.Clear();
	FormTableProducts.Columns.Add("Check", New TypeDescription("Boolean"));
	FormTableProducts.Columns.Add("Picture", New TypeDescription("Number"));
	FormTableProducts.Columns.Add("OriginalPrice", New TypeDescription("Number"));
	FormTableProducts.Columns.Add("KeyConnection", New TypeDescription("Number"));
	
	FormTableCharacteristics = FormTableProducts.Copy();
	
	For Each Row In DocumentTabularSection Do
		
		If ValueIsFilled(Row.Characteristic) Then
			NewRow = FormTableCharacteristics.Add();
		Else
			NewRow = FormTableProducts.Add();
		EndIf;
		
		FillPropertyValues(NewRow, Row);
		
		NewRow.KeyConnection = DocumentTabularSection.IndexOf(Row);
		NewRow.Check = True;
		
	EndDo;
	
	FormDataCollections = New Structure("FormTableProducts, FormTableCharacteristics", FormTableProducts, FormTableCharacteristics);
	
	PriceFormationParameters = New Structure;
	PriceFormationParameters.Insert("Formula", ParametersStructure.PriceKind.Formula);
	PriceFormationParameters.Insert("PriceTypesToRecalculate", Undefined);
	PriceFormationParameters.Insert("ShowCharacteristic", True);
	PriceFormationParameters.Insert("SetCharacteristicsWithoutPrice", True);
	PriceFormationParameters.Insert("FormDataCollections", FormDataCollections);
	PriceFormationParameters.Insert("Company", ParametersStructure.Company);
	
	PriceTypesToRecalculate = New Map;
	PriceTypesToRecalculate.Insert(ParametersStructure.PriceKind, ParametersStructure.PriceKind);
	
	PriceFormationParameters.PriceTypesToRecalculate = PriceTypesToRecalculate;
	
	CalculateNewPricesByFormula(PriceFormationParameters);
	
	For Each TempTable In PriceFormationParameters.FormDataCollections Do
		For Each RowTable In TempTable.Value Do
			DocumentTabularSection[RowTable.KeyConnection].Price = RowTable.Price;
			DocumentTabularSection[RowTable.KeyConnection].PriceIncludesVAT = ParametersStructure.PriceKind.PriceIncludesVAT;
		EndDo;
	EndDo;
	
	Return DocumentTabularSection;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

Procedure ParsingFormulaForOperands(Period, Formula, Operands, Company)
	
	FormulaText = TrimAll(Formula);
	If IsBlankString(FormulaText) Then
		Return;
	EndIf;
	
	OperandCharBegin = StringBeginOperand();
	OperandCharEnd = StringEndOperand();
	
	OperandsCount = StrOccurrenceCount(FormulaText, OperandCharBegin);
	
	While OperandsCount > 0 Do
		
		OperandBegin	= Find(FormulaText, OperandCharBegin);
		OperandEnd		= Find(FormulaText, OperandCharEnd);
		
		Operand	= Mid(FormulaText, OperandBegin, OperandEnd - OperandBegin + 1);
		ID		= StrReplace(StrReplace(Operand, OperandCharBegin, ""), OperandCharEnd, "");
		Result	= FindPriceTypeByID(ID);
		
		If Operands.Find(Operand, "Operand") <> Undefined Then
			Return;
		EndIf;
		
		NewOperand = Operands.Add();
		NewOperand.Operand				= Operand;
		NewOperand.PriceType 			= Result.PriceType;
		NewOperand.ThisIsProductsPrice 	= Result.ThisIsProductsPrice;
		
		If NewOperand.ThisIsProductsPrice <> Undefined Then
			
			PriceTypeCurrency = NewOperand.PriceType.PriceCurrency;
			
			If ValueIsFilled(PriceTypeCurrency) Then
				
				PriceTypeCurrencyData = CurrencyRateOperations.GetCurrencyRate(Period, PriceTypeCurrency, Company);
				
				NewOperand.PriceTypeExchangeRate = PriceTypeCurrencyData.Rate;
				NewOperand.PriceTypeMultiplicity = PriceTypeCurrencyData.Repetition;
				
			Else
				
				NewOperand.PriceTypeExchangeRate = 1;
				NewOperand.PriceTypeMultiplicity = 1;
				
			EndIf;
			
		EndIf;
		
		OperandsCount	= OperandsCount - StrOccurrenceCount(FormulaText, Operand);
		FormulaText		= StrReplace(FormulaText, Operand, "");
		
	EndDo;
	
EndProcedure

Procedure TransposeTablesCollectionsAndOperands(ProductsCollection, OperandsTable, OperandsMap, UseCurrentValue, ThisIsCollectionWithIndexes)
	
	ParametersNames = "";
	Query = New Query;
	
	Template_ParameterName = 
	"	,%1.Value AS Value_%1
		|	,%1.MeasurementUnit AS MeasurementUnit_%1
		|	,%1.ExchangeRate AS ExchangeRate_%1
		|	,%1.Multiplicity AS Multiplicity_%1";
	
	Template_PriceTypeParameter =
	"SELECT
	|	ParameterColectionValues.Products AS Products,
	|	ParameterColectionValues.Characteristic AS Characteristic,
	|	ParameterColectionValues.Value AS Value,
	|	ParameterColectionValues.ExchangeRate AS ExchangeRate,
	|	ParameterColectionValues.Multiplicity AS Multiplicity,
	|	ParameterColectionValues.MeasurementUnit AS MeasurementUnit
	|INTO ParameterColectionValues
	|FROM
	|	&ParameterColectionValues AS ParameterColectionValues
	|WHERE
	|	ParameterColectionValues.PriceType = &PriceTypeParameterName
	|
	|INDEX BY
	|	ParameterColectionValues.Products,
	|	ParameterColectionValues.Characteristic
	|;
	|//////////////////////////////////////////////////////////////////////
	|";
	
	Template_ParameterLeftJoin = "
	|
	|	LEFT JOIN ParameterColectionValues AS ParameterColectionValues
	|	ON ProductsCollection.Products = ParameterColectionValues.Products
	|		AND ProductsCollection.Characteristic = ParameterColectionValues.Characteristic
	|";
	
	Query.Text = "
	|
	|SELECT
	|	ProductsCollection.Period AS Period,
	|	ProductsCollection.PriceType AS PriceType,
	|	ProductsCollection.Products AS Products,
	|	ProductsCollection.Characteristic AS Characteristic,
	|	ProductsCollection.Price AS Price,
	|	ProductsCollection.CurrentValue AS CurrentValue,
	|	ProductsCollection.ProductsConnectionKey AS ProductsConnectionKey,
	|	ProductsCollection.CharacteristicConnectionKey AS CharacteristicConnectionKey,
	|	ProductsCollection.Actual AS Actual,
	|	ProductsCollection.MeasurementUnit AS MeasurementUnit,
	|	ProductsCollection.UseCharacteristic AS UseCharacteristic,
	|	ProductsCollection.Autor AS Autor,
	|	ProductsCollection.Formula AS Formula,
	|	ProductsCollection.RecountCompleted AS RecountCompleted
	|INTO ProductsCollection
	|FROM
	|	&ProductsCollection AS ProductsCollection
	|
	|INDEX BY
	|	ProductsCollection.Products,
	|	ProductsCollection.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductsCollection.Period AS Period,
	|	ProductsCollection.PriceType AS PriceType,
	|	ProductsCollection.Products AS Products,
	|	ProductsCollection.Characteristic AS Characteristic,
	|	ProductsCollection.Price AS Price,
	|	ProductsCollection.CurrentValue AS CurrentValue,
	|	ProductsCollection.ProductsConnectionKey AS ProductsConnectionKey,
	|	ProductsCollection.CharacteristicConnectionKey AS CharacteristicConnectionKey,
	|	ProductsCollection.Actual AS Actual,
	|	ProductsCollection.MeasurementUnit AS MeasurementUnit,
	|	ProductsCollection.UseCharacteristic AS UseCharacteristic,
	|	ProductsCollection.Autor AS Autor,
	|	ProductsCollection.Formula AS Formula,
	|	ProductsCollection.RecountCompleted AS RecountCompleted
	|	,&ParametersNames
	|FROM
	|	ProductsCollection AS ProductsCollection";
	
	If NOT UseCurrentValue Then
		
		Query.Text = StrReplace(Query.Text, ",ProductsCollection.CurrentValue", "");
		
	EndIf;
	
	If NOT ThisIsCollectionWithIndexes Then
		
		Query.Text = StrReplace(Query.Text, ",ProductsCollection.ProductsConnectionKey", "");
		Query.Text = StrReplace(Query.Text, ",ProductsCollection.CharacteristicConnectionKey", "");
		
	EndIf;
	
	For Each OperandRow In OperandsTable Do
		
		OperandsMap.Insert(OperandRow.Operand, 0);
		
		If TypeOf(OperandRow.Value) = Type("ValueTable") Then
			
			If OperandRow.ThisIsProductsPrice <> Undefined Then
				
				ID = OperandRow.PriceType.OperandID;
				Query.SetParameter("Parameter_" + ID, OperandRow.PriceType);
				
				QueryTextParametersCollection = StrReplace(Template_PriceTypeParameter, "&PriceTypeParameterName", "&Parameter_" + ID);
				
			EndIf;
			
			QueryTextParametersCollection	= StrReplace(QueryTextParametersCollection, "ParameterColectionValues", ID);
			QueryTextParameterLeftJoin		= StrReplace(Template_ParameterLeftJoin, "ParameterColectionValues", ID);
			ParametersNames					= ParametersNames + StrTemplate(Template_ParameterName, ID);
			
			Query.SetParameter(ID, OperandRow.Value);
			
			Query.Text = QueryTextParametersCollection + Query.Text + QueryTextParameterLeftJoin;
			
		EndIf;
		
	EndDo;
	
	Query.Text = StrReplace(Query.Text, ",&ParametersNames", ParametersNames);
	Query.SetParameter("ProductsCollection", ProductsCollection);
	
	ProductsCollection = Query.Execute().Unload();
	
EndProcedure

Procedure GetTableFormulaOperandsPrices(CalculateParameters, TableOperands)
	
	Query = New Query;
	Query.SetParameter("FormTableProducts", CalculateParameters.FormDataCollections.FormTableProducts);
	Query.SetParameter("FormTableCharacteristics", CalculateParameters.FormDataCollections.FormTableCharacteristics);
	
	Query.Text =
	"SELECT
	|	FormTableProducts.Products AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic
	|INTO TableProducts
	|FROM
	|	&FormTableProducts AS FormTableProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FormTableCharacteristics.Products AS Products,
	|	FormTableCharacteristics.Characteristic AS Characteristic
	|INTO TableCharacteristics
	|FROM
	|	&FormTableCharacteristics AS FormTableCharacteristics
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TRUE AS IsNeedNewCalculation
	|FROM
	|	TableProducts AS TableProducts
	|
	|UNION ALL
	|
	|SELECT
	|	TableCharacteristics.Products,
	|	TableCharacteristics.Characteristic,
	|	TRUE
	|FROM
	|	TableCharacteristics AS TableCharacteristics";
	
	TableProductsAndCharacteristics = Query.Execute().Unload();
	
	PriceGenerationServer.PricesValuesToTableOperands(BegOfDay(CurrentSessionDate()), TableOperands, TableProductsAndCharacteristics);
	
	TableProductsAndCharacteristics = Undefined;
	
EndProcedure

Procedure GetOperandsAndData(CalculateParameters, TableOperands)
	
	Var PreparedTableData;
	
	If CalculateParameters.Property("Period") Then
		
		Period = BegOfDay(?(ValueIsFilled(CalculateParameters.Period), CalculateParameters.Period, CurrentSessionDate()));
		
	EndIf;
	
	TableOperands = GetOperandsFormulaTable(Period, CalculateParameters);
	TableOperands.Columns.Add("Value");
	
	ProductsPricesArray = TableOperands.FindRows(New Structure("ThisIsProductsPrice", True));
	SuppliersPricesArray = TableOperands.FindRows(New Structure("ThisIsProductsPrice", False));
	
	If ProductsPricesArray.Count() > 0 OR SuppliersPricesArray.Count() > 0 Then
		
		GetTableFormulaOperandsPrices(CalculateParameters, TableOperands);
		
	EndIf;
	
EndProcedure

Procedure MergingDataInGeneralTable(CalculateParameters, ProductsCollection, PriceType)
	
	ProductsCollection = New ValueTable;
	ProductsCollection.Columns.Add("ProductsConnectionKey",			New TypeDescription("Number"));
	ProductsCollection.Columns.Add("CharacteristicConnectionKey",	New TypeDescription("Number"));
	ProductsCollection.Columns.Add("Period", 						New TypeDescription("Date"));
	ProductsCollection.Columns.Add("PriceType", 					New TypeDescription("CatalogRef.PriceTypes"));
	ProductsCollection.Columns.Add("Products",						New TypeDescription("CatalogRef.Products"));
	ProductsCollection.Columns.Add("Characteristic",				New TypeDescription("CatalogRef.ProductsCharacteristics"));
	ProductsCollection.Columns.Add("Price",							New TypeDescription("Number"));
	ProductsCollection.Columns.Add("MeasurementUnit",				New TypeDescription("CatalogRef.UOM, CatalogRef.UOMClassifier"));
	ProductsCollection.Columns.Add("CurrentValue",					New TypeDescription("Number"));
	ProductsCollection.Columns.Add("Actual",						New TypeDescription("Boolean"));
	ProductsCollection.Columns.Add("UseCharacteristic",				New TypeDescription("Boolean"));
	ProductsCollection.Columns.Add("Autor",							New TypeDescription("CatalogRef.Users"));
	ProductsCollection.Columns.Add("Formula",						New TypeDescription("String"));
	ProductsCollection.Columns.Add("RecountCompleted",				New TypeDescription("Boolean"));
	
	EmptyCharacteristic = Catalogs.ProductsCharacteristics.EmptyRef();
	PriceTypeID = "TabularProducts" + PriceType.OperandID;
	
	For Each RowProducts In CalculateParameters.FormDataCollections.FormTableProducts Do
		
		NewRow = ProductsCollection.Add();
		NewRow.ProductsConnectionKey		= RowProducts.KeyConnection;
		NewRow.CharacteristicConnectionKey	= -1;
		NewRow.Products						= RowProducts.Products;
		NewRow.Characteristic				= EmptyCharacteristic;
		NewRow.UseCharacteristic			= CalculateParameters.SetCharacteristicsWithoutPrice;
		NewRow.CurrentValue					= RowProducts["OriginalPrice"];
		NewRow.MeasurementUnit				= RowProducts["MeasurementUnit"];
		NewRow.PriceType 					= PriceType;
		NewRow.Formula						= CalculateParameters.Formula;
		
	EndDo;
	
	PriceTypeID = "TabularCharacteristics" + PriceType.OperandID;
	
	For Each RowCharacteristic In CalculateParameters.FormDataCollections.FormTableCharacteristics Do
		
		NewRow = ProductsCollection.Add();
		NewRow.ProductsConnectionKey		= -1;
		NewRow.CharacteristicConnectionKey	= RowCharacteristic.KeyConnection;
		NewRow.Products						= RowCharacteristic.Products;
		NewRow.Characteristic				= RowCharacteristic.Characteristic;
		NewRow.UseCharacteristic			= CalculateParameters.SetCharacteristicsWithoutPrice;
		NewRow.CurrentValue					= RowCharacteristic["OriginalPrice"];
		NewRow.MeasurementUnit				= RowCharacteristic["MeasurementUnit"];
		NewRow.PriceType 					= PriceType;
		NewRow.Formula						= CalculateParameters.Formula;
		
	EndDo;
	
EndProcedure

Procedure RecalculatedRowsInDataTables(CalculateParameters, ProductsCollection, PriceType)
	
	PriceTypeID = PriceType.OperandID;
	FilterParameters = New Structure;
	
	For Each RowCollection In ProductsCollection Do
		
		FilterParameters.Clear();
		If RowCollection.CharacteristicConnectionKey < 0 Then
			
			ID = "TabularProducts" + PriceTypeID;
			TableName = "FormTableProducts";
			FilterParameters.Insert("KeyConnection", RowCollection.ProductsConnectionKey);
			FilterParameters.Insert("Products", RowCollection.Products);
			
		Else
			
			ID = "TabularCharacteristics" + PriceTypeID;
			TableName = "FormTableCharacteristics";
			FilterParameters.Insert("KeyConnection", RowCollection.CharacteristicConnectionKey);
			FilterParameters.Insert("Products", RowCollection.Products);
			FilterParameters.Insert("Characteristic", RowCollection.Characteristic);
			
		EndIf;
		
		RowSet = CalculateParameters.FormDataCollections[TableName].FindRows(FilterParameters);
		For Each RowTabular In RowSet Do
			
			RowTabular["Price"] = RowCollection.Price;
			RowTabular["MeasurementUnit"] = RowCollection.MeasurementUnit;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure CalculateNewPricesByFormula(CalculateParameters)
	
	Var ProductsCollection, TableOperands;
	
	CollectionCalculateParameters = New Structure("PriceType, ExchangeRate, Multiplicity");
	
	GetOperandsAndData(CalculateParameters, TableOperands);
	For Each ItemMap In CalculateParameters.PriceTypesToRecalculate Do
		
		ProductsCollection = Undefined;
		
		CollectionCalculateParameters.PriceType = ItemMap.Key;
		CollectionCalculateParameters.ExchangeRate = 1;
		CollectionCalculateParameters.Multiplicity = 1;
		
		If ValueIsFilled(CollectionCalculateParameters.PriceType) Then
			
			CurrencyData = CurrencyRateOperations.GetCurrencyRate(CurrentSessionDate(), CollectionCalculateParameters.PriceType.PriceCurrency, CalculateParameters.Company);
			CollectionCalculateParameters.ExchangeRate = ?(ValueIsFilled(CurrencyData.Rate), CurrencyData.Rate, 1);
			CollectionCalculateParameters.Multiplicity = ?(ValueIsFilled(CurrencyData.Repetition), CurrencyData.Repetition, 1);
			
		EndIf;
		
		MergingDataInGeneralTable(CalculateParameters, ProductsCollection, CollectionCalculateParameters.PriceType);
		CalculateDataCollection(ProductsCollection, 
			TableOperands,
			CollectionCalculateParameters,
			True,
			True);
		RecalculatedRowsInDataTables(CalculateParameters, ProductsCollection, CollectionCalculateParameters.PriceType);
		
	EndDo;
	
EndProcedure

#EndRegion