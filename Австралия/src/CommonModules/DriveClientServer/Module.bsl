
// Function returns the label text "Prices and currency".
//
Function GenerateLabelPricesAndCurrency(LabelStructure) Export
	
	LabelText = "";
	
	If LabelStructure.Property("ForeignExchangeAccounting") And LabelStructure.ForeignExchangeAccounting Then
		If LabelStructure.Property("DocumentCurrency") And ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = TrimAll(String(LabelStructure.DocumentCurrency));
		EndIf;
	EndIf;
	
	If LabelStructure.Property("PriceKind") And ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	If LabelStructure.Property("DiscountKind") And ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, TrimAll(String(LabelStructure.DiscountKind)));
	EndIf;
	
	If LabelStructure.Property("SupplierDiscountKind") And ValueIsFilled(LabelStructure.SupplierDiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, TrimAll(String(LabelStructure.SupplierDiscountKind)));
	EndIf;
	
	If LabelStructure.Property("DiscountPercentByDiscountCard")
		And LabelStructure.Property("DiscountCard")
		And ValueIsFilled(LabelStructure.DiscountCard) Then
		
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(
			LabelText, 
			String(LabelStructure.DiscountPercentByDiscountCard)
				+ NStr("en = '% by card'; ru = '% по карте';pl = '% kartą';es_ES = '% por tarjeta';es_CO = '% por tarjeta';tr = '% kartla';it = '% con carta';de = '% per Karte'"));
		
	EndIf;
	
	If LabelStructure.Property("SupplierPriceTypes") And ValueIsFilled(LabelStructure.SupplierPriceTypes) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, TrimAll(String(LabelStructure.SupplierPriceTypes)));
	EndIf;
	
	If LabelStructure.Property("VATTaxation")
		And (Not LabelStructure.Property("RegisteredForVAT")
			Or LabelStructure.RegisteredForVAT
			Or LabelStructure.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT")
			Or LabelStructure.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ForExport")) Then
		
		If ValueIsFilled(LabelStructure.VATTaxation) Then
			If IsBlankString(LabelText) Then
				LabelText = LabelText + "%1";
			Else
				LabelText = LabelText + " • %1";
			EndIf;
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText, TrimAll(String(LabelStructure.VATTaxation)));
		EndIf;
		
	EndIf;
	
	If LabelStructure.Property("AmountIncludesVAT")
		And LabelStructure.Property("VATTaxation")
		And LabelStructure.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If IsBlankString(LabelText) Then
			LabelText = LabelText + "%1";
		Else
			LabelText = LabelText + " • %1";
		EndIf;
		
		If LabelStructure.AmountIncludesVAT Then
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText,
				NStr("en = 'Tax inclusive'; ru = 'С учетом налогов';pl = 'Wartość brutto';es_ES = 'Con impuestos';es_CO = 'Con impuestos';tr = 'Vergi dahil';it = 'IVA inclusa';de = 'Inklusive Steuer'"));
		Else
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText,
				NStr("en = 'Tax exclusive'; ru = 'Без учета налогов';pl = 'Bez podatku';es_ES = 'No incluye impuestos';es_CO = 'No incluye impuestos';tr = 'Vergi hariç';it = 'Iva esclusa';de = 'Abzgl. Steuer'"));
		EndIf;
		
	EndIf;
	
	If LabelStructure.Property("RegisteredForSalesTax") And LabelStructure.RegisteredForSalesTax Then
		
		If LabelStructure.Property("SalesTaxRate") And ValueIsFilled(LabelStructure.SalesTaxRate) Then
			
			If IsBlankString(LabelText) Then
				LabelText = LabelText + "%1";
			Else
				LabelText = LabelText + " • %1";
			EndIf;
			
			LabelText = StringFunctionsClientServer.SubstituteParametersToString(LabelText,
				TrimAll(String(LabelStructure.SalesTaxRate)));
			
		EndIf;
		
	EndIf;
	
	Return LabelText;
	
EndFunction

// Fills in the values list Receiver from the values list Source
//
Procedure FillListByList(Source,Receiver) Export

	Receiver.Clear();
	For Each ListIt In Source Do
		Receiver.Add(ListIt.Value, ListIt.Presentation);
	EndDo;

EndProcedure

// Function receives items present in each array
//
// Parameters:
//  Array1	 - array	 - first
//  array Array2	 - array	 - second
// array Return value:
//  array - array of values that are contained in two arrays
Function GetMatchingArraysItems(Array1, Array2) Export
	
	Result = New Array;
	
	For Each Value In Array1 Do
		If Array2.Find(Value) <> Undefined Then
			Result.Add(Value);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure SetPictureForComment(GroupAdditional, Comment) Export
	
	If ValueIsFilled(Comment) Then
		GroupAdditional.Picture = PictureLib.WriteSMS;
	Else
		GroupAdditional.Picture = New Picture;
	EndIf;
	
EndProcedure

Function PluralForm(Word1, Word2, Word3, Val IntegerNumber) Export
	
	// Change the sign of an integer, otherwise negative numbers will be incorrectly converted
	If IntegerNumber < 0 Then
		IntegerNumber = -1 * IntegerNumber;
	EndIf;
	
	If IntegerNumber <> Int(IntegerNumber) Then 
		// For non-integer numbers - always the second form
		Return Word2;
	EndIf;
	
	// remainder
	Remainder = IntegerNumber%10;
	If (IntegerNumber >10) AND (IntegerNumber<20) Then
		// For the second ten - always the third form
		Return Word3;
	ElsIf Remainder=1 Then
		Return Word1;
	ElsIf (Remainder>1) AND (Remainder<5) Then
		Return Word2;
	Else
		Return Word3;
	EndIf;

EndFunction

// Fills the connection key of the
// document table or data processor.
Procedure FillConnectionKey(TabularSection, TabularSectionRow, ConnectionAttributeName, TempConnectionKey = 0) Export
	
	If Not ValueIsFilled(TabularSectionRow[ConnectionAttributeName]) Then
		
		If TempConnectionKey = 0 Then
			
			For Each TSRow In TabularSection Do
				If TempConnectionKey < TSRow[ConnectionAttributeName] Then
					TempConnectionKey = TSRow[ConnectionAttributeName];
				EndIf;
			EndDo;
			
		EndIf;
		
		TabularSectionRow[ConnectionAttributeName]	= TempConnectionKey + 1;
		TempConnectionKey							= TempConnectionKey + 1;
		
	EndIf;
	
EndProcedure

// Deletes the rows on the connection key in the
// document table or data processors.
Procedure DeleteRowsByConnectionKey(TabularSection, TabularSectionRow, ConnectionAttributeName = "ConnectionKey") Export
	
	If TabularSectionRow = Undefined Then
		Return;
	EndIf;
	
	TheStructureOfTheSearch = New Structure;
	TheStructureOfTheSearch.Insert(ConnectionAttributeName, TabularSectionRow[ConnectionAttributeName]);
	
	RowsToDelete = TabularSection.FindRows(TheStructureOfTheSearch);
	For Each TableRow In RowsToDelete Do
		
		TabularSection.Delete(TableRow);
		
	EndDo;
	
EndProcedure

// Calculates nearest start date for specified period
//
// Parameters:
// StartDate	- date, for which nearest start date will be calculated
// Periodicity	- value from enumeration "Periodicity"
//
// Returns:
// Date - nearest start date for specified period
//
Function CalculateComingPeriodStartDate(StartDate, Periodicity) Export
	
	OneDay = 86400;
	ComingDate = StartDate;
	
	If Periodicity = PredefinedValue("Enum.Periodicity.Day") Then
		
		ComingDate = StartDate;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Week") Then
		
		If StartDate = BegOfWeek(StartDate) Then
			ComingDate = StartDate;
		Else
			ComingDate = EndOfWeek(StartDate) + OneDay;
		EndIf;
		
	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.TenDays")) Then
		
		DayOfMonth = Day(StartDate);
		BegOfMonth = BegOfMonth(StartDate);
		
		If DayOfMonth = 1 Or DayOfMonth = 11 Or DayOfMonth = 21 Then
			ComingDate = StartDate;
		ElsIf DayOfMonth <= 10 Then
			ComingDate = BegOfMonth + OneDay * 10;
		ElsIf DayOfMonth <= 20 Then
			ComingDate = BegOfMonth + OneDay * 20;
		Else
			ComingDate = EndOfMonth(BegOfMonth) + OneDay;
		EndIf;
		
	ElsIf (Periodicity= PredefinedValue("Enum.Periodicity.Month")) Then
		
		If StartDate = BegOfMonth(StartDate) Then
			ComingDate = StartDate;
		Else
			ComingDate = EndOfMonth(StartDate) + OneDay;
		EndIf;

	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.Quarter")) Then
		
		If StartDate = BegOfQuarter(StartDate) Then
			ComingDate = StartDate;
		Else
			ComingDate = EndOfQuarter(StartDate) + OneDay;
		EndIf;

	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.HalfYear")) Then
		
		BegOfYear		= BegOfYear(StartDate);
		HalfYearStart	= AddMonth(BegOfYear, 6);
		
		If StartDate = HalfYearStart Or StartDate = BegOfYear Then
			ComingDate = StartDate;
		Else
			ComingDate = ?(StartDate > HalfYearStart, EndOfYear(StartDate) + OneDay, HalfYearStart);
		EndIf;

	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.Year")) Then
		
		If StartDate = BegOfYear(StartDate) Then
			ComingDate = StartDate;
		Else
			ComingDate = EndOfYear(StartDate) + OneDay;
		EndIf;

	EndIf;
	
	Return ComingDate;
	
EndFunction

// Calculates period end date
//
// Parameters:
// StartDate			- start date, for which you need to calculate end of period
// Periodicity			- value from enumeration "Periodicity"
// PeriodsQuantity		- number of period repeats
//
// Returns:
// Date - Period end date
//
Function CalculatePeriodEndDate(StartDate, Periodicity, PeriodsQuantity) Export

	OneDay = 86400;

	If Periodicity = PredefinedValue("Enum.Periodicity.Day") Then 
		
		EndDate = StartDate + OneDay * PeriodsQuantity;

	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Week") Then
		
		EndDate = StartDate + OneDay * 7 * PeriodsQuantity;

	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.TenDays")) Then
		
		DayOfMonth = Day(StartDate);
		BegOfMonth = BegOfMonth(StartDate);
		
		If DayOfMonth <= 10 Then
			DacadeNumber = 1;
		ElsIf DayOfMonth <= 20 Then
			DacadeNumber = 2;
		Else
			DacadeNumber = 3;
		EndIf;
			
		DacadeNumber = DacadeNumber + PeriodsQuantity;
		
		If DacadeNumber > 0 Then
			MonthNumber = Int((DacadeNumber - 1) / 3);
		Else
			MonthNumber = -1 - Int((-DacadeNumber) / 3);
		EndIf;
		
		DacadeNumber = DacadeNumber - 3 * MonthNumber;
		TempDate = AddMonth(BegOfMonth, MonthNumber) + (DacadeNumber - 1) * 10 * OneDay;

		If PeriodsQuantity > 0 Then
			
			EndDate = TempDate;
			
		Else
			
			DayOfMonth = Day(TempDate);
			
			If DayOfMonth <= 10 Then
				EndDate = EndOfDay(BegOfMonth(TempDate) + OneDay * 9);
			ElsIf DayOfMonth <= 20 Then
				EndDate = EndOfDay(BegOfMonth(TempDate) + OneDay * 19);
			Else
				EndDate = EndOfMonth(TempDate);
			EndIf;
			
		EndIf;
		
	ElsIf (Periodicity= PredefinedValue("Enum.Periodicity.Month")) Then
		
		EndDate = AddMonth(StartDate, PeriodsQuantity);
		
	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.Quarter")) Then
		
		EndDate = AddMonth(StartDate, 3 * PeriodsQuantity);
		
	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.HalfYear")) Then
		
		EndDate = AddMonth(StartDate, 6 * PeriodsQuantity);
		
	ElsIf (Periodicity = PredefinedValue("Enum.Periodicity.Year")) Then
		
		EndDate = AddMonth(StartDate, 12 * PeriodsQuantity);
		
	EndIf;
	
	Return EndOfDay(EndDate-OneDay);

EndFunction

// Rounds a number according to a specified order.
//
// Parameters:
//  Number        - Number required
//  to be rounded RoundingOrder - Enums.RoundingMethods - round
//  order RoundUpward - Boolean - rounding upward.
//
// Returns:
//  Number        - rounding result.
//
Function RoundPrice(Number, RoundRule, RoundUp = False, PricePrecision = 0) Export
	
	Var Result; // Returned result.
	
	// Transform order of numbers rounding.
	// If null order value is passed, then round to cents.
	If Not ValueIsFilled(RoundRule) Then
		RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_01"); 
	Else
		RoundingOrder = RoundRule;
	EndIf;
	Order = NumberByRoundingOrder(RoundingOrder);
	
	// calculate quantity of intervals included in number
	QuantityInterval = Number / Order;
	
	// calculate an integer quantity of intervals.
	NumberOfEntireIntervals = Int(QuantityInterval);
	
	If QuantityInterval = NumberOfEntireIntervals Then
		
		// Numbers are divided integrally. No need to round.
		Result = Number;
	Else
		If RoundUp Then
			
			// During 0.05 rounding 0.371 must be rounded to 0.4
			Result = Order * (NumberOfEntireIntervals + 1);
		Else
			
			// During 0.05 rounding 0.371 must be rounded to 0.35 and 0.376 to 0.4
			Result = Order * Round(QuantityInterval, PricePrecision, RoundMode.Round15as20);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

Function NumberByRoundingOrder(RoundingOrder) Export
	
	If RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_01") Then
		Result = 0.01;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_05") Then
		Result = 0.05;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round1") Then
		Result = 1;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round5") Then
		Result = 5;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round10") Then
		Result = 10;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round50") Then
		Result = 50;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round100") Then
		Result = 100;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_1") Then
		Result = 0.1;
	ElsIf RoundingOrder = PredefinedValue("Enum.RoundingMethods.Round0_5") Then
		Result = 0.5;
	EndIf;
	
	Return Result;
	
EndFunction

Function BooleanToYesNo(BooleanValue) Export
	
	If BooleanValue Then
		Return PredefinedValue("Enum.YesNo.Yes");
	Else
		Return PredefinedValue("Enum.YesNo.No");
	EndIf;
	
EndFunction

Function YesNoToBoolean(YesNoValue) Export
	Return (YesNoValue = PredefinedValue("Enum.YesNo.Yes"));
EndFunction

Procedure ProductionTasksErrorMessage(ProductionTaskRef) Export
	
	ErrorMessage = StrTemplate(
		NStr("en = 'Cannot perform this action for Production task %1. Close all Production task windows and try again.'; ru = 'Не удается выполнить это действие для производственной задачи %1. Закройте все окна производственных задач и повторите попытку.';pl = 'Nie można wykonać tego działania dla Zadania produkcyjnego %1. Zamknij wszystkie okna dialogowe z zadaniami produkcyjnymi i spróbuj ponownie.';es_ES = 'No se puede realizar esta acción para la tarea de producción %1. Cierre todas las ventanas de la tarea de producción e inténtelo de nuevo.';es_CO = 'No se puede realizar esta acción para la tarea de producción %1. Cierre todas las ventanas de la tarea de producción e inténtelo de nuevo.';tr = '%1 Üretim görevi için bu işlem gerçekleştirilemiyor. Tüm Üretim görevi pencerelerini kapatıp tekrar deneyin.';it = 'Impossibile eseguire questa azione per l''Incarico di produzione %1. Chiudere tutte le finestre dell''Incarico di produzione e riprovare.';de = 'Diese Aktion kann für Produktionsaufgabe %1 nicht ausgeführt werden. Schließen Sie alle Produktionsaufgabenfenster, und versuchen Sie es erneut.'"),
		ProductionTaskRef);
	CommonClientServer.MessageToUser(ErrorMessage);
	
EndProcedure

Procedure FillInCurrencyRateChoiceList(Form, CurRateItemName, AdditionalParameters) Export
	
	ChoiceList = Form.Items[CurRateItemName].ChoiceList;
	ChoiceList.Clear();
	
	NewChoiceList = DriveServerCall.GetCurrencyRateChoiceList(AdditionalParameters.Currency, 
		AdditionalParameters.PresentationCurrency,
		AdditionalParameters.DocumentDate,
		AdditionalParameters.Company);
		
	For Each Row In NewChoiceList Do
		ChoiceList.Add(Row.Value, Row.Presentation);
	EndDo;
	
EndProcedure

#Region WorkWithDatePrecision

Function DatePrecisionFormatString(Precision) Export
	
	If Precision = PredefinedValue("Enum.DatePrecision.Year") Then
		
		Return "DF=yyyy";
		
	ElsIf Precision = PredefinedValue("Enum.DatePrecision.Month") Then
		
		Return NStr("en = 'DF=MM/yyyy'; ru = 'DF=MM.yyyy';pl = 'DF=MM.yyyy';es_ES = 'DF=MM/yyyy';es_CO = 'DF=MM/yyyy';tr = 'DF=MM.yyyy';it = 'DF = MM/yyyy';de = 'DF=MM/yyyy'");
		
	ElsIf Precision = PredefinedValue("Enum.DatePrecision.Day") Then
		
		Return "DLF=D";
		
	ElsIf Precision = PredefinedValue("Enum.DatePrecision.Hour") Then
		
		Return "DLF=DT";
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

Function AdjustDateByPrecision(Date, Precision) Export
	
	If Precision = PredefinedValue("Enum.DatePrecision.Year") Then
		
		Return BegOfYear(Date);
		
	ElsIf Precision = PredefinedValue("Enum.DatePrecision.Month") Then
		
		Return BegOfMonth(Date);
		
	ElsIf Precision = PredefinedValue("Enum.DatePrecision.Day") Then
		
		Return BegOfDay(Date);
		
	ElsIf Precision = PredefinedValue("Enum.DatePrecision.Hour") Then
		
		Return BegOfHour(Date);
		
	Else
		
		Return Date;
		
	EndIf;
	
EndFunction

#EndRegion

#Region Print

Procedure ComplimentProductDescription(ProductDescription, ProductsSelection, SerialNumbersSelection = Undefined) Export
	
	If Not ProductsSelection.ContentUsed Then
	
		AdditionalProductDescriptonComponents = New Array;
		
		If ValueIsFilled(ProductsSelection.Characteristic) Then
			
			AdditionalProductDescriptonComponents.Add(ProductsSelection.CharacteristicDescription);
			
		EndIf;
		
		If ValueIsFilled(ProductsSelection.Batch) Then
			
			AdditionalProductDescriptonComponents.Add(ProductsSelection.BatchDescription);
			
		EndIf;
		
		If SerialNumbersSelection <> Undefined 
			AND ProductsSelection.UseSerialNumbers Then
			
			SNSearchStructure = New Structure("Ref, ConnectionKey");
			FillPropertyValues(SNSearchStructure, ProductsSelection);
			
			SerialNumbersSelection.Reset();
			While SerialNumbersSelection.FindNext(SNSearchStructure) Do
				
				AdditionalProductDescriptonComponents.Add(SerialNumbersSelection.SerialNumber);
				
			EndDo;
			
		EndIf;
		
		If AdditionalProductDescriptonComponents.Count() Then
			
			AdditionalDescription = StrConcat(AdditionalProductDescriptonComponents, ", ");
			
			ProductDescription = ProductDescription + " (" + AdditionalDescription + ")";
			
		EndIf;
		
		If TypeOf(ProductsSelection) = Type("ValueTableRow")
			And ProductsSelection.IsBundle Then
			
			ProductDescription = "    • " + ProductDescription;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithQuery

Function GetQueryUnion() Export
	
	Return "
	|
	|UNION ALL
	|
	|";
	
EndFunction

Function GetQueryDelimeter() Export
	
	Return "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
EndFunction

// Add delimeter to query text.
//
// Parameters:
//	QueryText - String - Query text
//
Procedure AddDelimeter(QueryText) Export
	
	If ValueIsFilled(QueryText) Then
		QueryText = QueryText + GetQueryDelimeter();
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithArray

// Create array from item.
//
// Parameters:
//	Item - Array, ValueList, FixedArray - Value will convert to array.
//	IgnoreEmptyValue - Boolean - Ignore empty Item (no value)
//
// Returned value:
//	Array
//
Function ArrayFromItem(Item, IgnoreEmptyValue = True) Export
	
	If TypeOf(Item) = Type("Array") Then
		Array = Item;
	ElsIf TypeOf(Item) = Type("ValueList") Then
		Array = Item.UnloadValues();
	ElsIf TypeOf(Item) = Type("FixedArray") Then
		Array = New Array(Item);
	Else
		Array = New Array;
		If Not IgnoreEmptyValue Or ValueIsFilled(Item) Then
			Array.Add(Item);
		EndIf;
	EndIf;
	
	Return Array;
	
EndFunction

// Add new value into array.
//
// Parameters:
//	Array - Array - Source array
//	Value - Any value - Value for add into array
//
// Returned value:
//	Array
//
Function AddNewValueInArray(Array, Value) Export
	
	ValueIsAdded = False;
	
	If Array.Find(Value) = Undefined Then
		Array.Add(Value);
		ValueIsAdded = True;
	EndIf;
	
	Return ValueIsAdded;
EndFunction

// Return the intersecrion of two arrays.
//
// Parameters:
//	Array1 - Array - The first array
//	Array2 - Array - The second array
//
// Returned value:
//	Array
//
Function IntersecrionOfArrays(Array1, Array2) Export
	
	Intersecrion = New Array;
	
	For Each CurrentItem In Array1 Do
		If Array2.Find(CurrentItem) <> Undefined Then
			AddNewValueInArray(Intersecrion, CurrentItem);
		EndIf;
	EndDo;
	
	Return Intersecrion;
EndFunction

// Return fixed array for ChoiceParameters.
//
// Parameters:
//	Values - Can be of any type. For a list of values, use an array
//	StringNameOfFilter - String - Name of filter. Example - "Filter.OperationKind"
//	IsReturnEmpty - Boolean - Return empty fixed array
//
// Returned value:
//	Array
//
Function GetFixedArrayChoiceParameters(Values, StringNameOfFilter, IsReturnEmpty = False) Export
	
	If IsReturnEmpty Then
	
		FixedArrayParameters	= New FixedArray(New Array);
	
	Else
		
		If TypeOf(Values) = Type("Array") Then
			Values		= New FixedArray(Values);
		EndIf;
		
		ChoiceParameterFilter	= New ChoiceParameter(StringNameOfFilter, Values);
		ArrayParameters			= New Array();
		ArrayParameters.Add(ChoiceParameterFilter);
		FixedArrayParameters	= New FixedArray(ArrayParameters);
	
	EndIf;
	
	Return FixedArrayParameters;
	
EndFunction

#EndRegion

#Region WorkWithStructure

// Checks that not elements in structure with empty values
//
// Parameters:
//	Data - Structure
//
// Returned value:
//	Boolean - If not empty values in structure is True.
//
Function ValuesInStructureNotFilled(Data) Export
	
	EmptyValues = True;
	
	For Each KeyAndValue In Data Do
		
		If (TypeOf(KeyAndValue.Value) = Type("Boolean") AND KeyAndValue.Value)
			OR (TypeOf(KeyAndValue.Value) <> Type("Boolean") AND ValueIsFilled(KeyAndValue.Key)) Then
			EmptyValues = False;
			Break;
		EndIf;
		
	EndDo;
	
	Return EmptyValues;
EndFunction

Function StructureToString(StructureForTransformation, Separator = ",") Export
	
	Result = "";
	
	For Each Item In StructureForTransformation Do
		
		SeparatorChar = ?(IsBlankString(Result), "", Separator);
		
		Result = Result + SeparatorChar + Item.Key;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function StringToStructure(StringForTransformation, Separator = ",") Export
	
	Result	= New Structure;
	StringPropertySearch	= StringForTransformation;
	
	SeparatorPosition = StrFind(StringPropertySearch,Separator);
	
	While SeparatorPosition <> 0 Do
		Result.Insert(TrimAll(Left(StringPropertySearch, SeparatorPosition-1)));
		StringPropertySearch = Mid(StringPropertySearch, SeparatorPosition+1);
		SeparatorPosition = StrFind(StringPropertySearch, Separator);
	EndDo;
	
	Result.Insert(TrimAll(StringPropertySearch));
	
	Return Result;
	
EndFunction

#EndRegion

#Region InteractionProceduresAndFunctions

// Generates a structure of contact info fields of type Telephone or MobilePhone by a telephone presentation
//
// Parameters
//  Presentation  - String - String info with a telephone number
//
// Returns:
//   Structure   - generated structure
//
Function ConvertNumberForSMSSending(val Number) Export
	
	// Clear user separators
	CharsToReplace = "()- ";
	For CharacterNumber = 1 To StrLen(CharsToReplace) Do
		Number = StrReplace(Number, Mid(CharsToReplace, CharacterNumber, 1), "");
	EndDo;
	
	Return Number;
	
EndFunction

// PROCEDURES AND FUNCTIONS OF WORK WITH DYNAMIC LISTS

// Procedure sets filter in dynamic list for equality.
//
Procedure SetDynamicListFilterToEquality(Filter, LeftValue, RightValue) Export
	
	FilterItem = Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue	 = LeftValue;
	FilterItem.ComparisonType	 = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = RightValue;
	FilterItem.Use  = True;
	
EndProcedure

// Deletes dynamic list filter item
//
// Parameters:
// List  - processed dynamic
// list, FieldName - layout field name filter by which should be deleted
//
Procedure DeleteListFilterItem(List, FieldName) Export
	
	SetElements = List.SettingsComposer.Settings.Filter;
	CommonClientServer.DeleteFilterItems(SetElements,FieldName);
	
EndProcedure

// Sets dynamic list filter item
//
// Parameters:
// List			- processed dynamic
// list, FieldName			- layout field name filter on which
// should be set, ComparisonKind		- filter comparison kind, by default - Equal,
// RightValue 	- filter value
//
Procedure SetListFilterItem(List, FieldName, RightValue, Use = True, ComparisonType = Undefined) Export
	
	SetElements = List.SettingsComposer.Settings.Filter;
	CommonClientServer.SetFilterItem(SetElements,FieldName,RightValue,ComparisonType,,Use);
	
EndProcedure

// Changes dynamic list filter item
//
// Parameters:
// List         - processed dynamic
// list, FieldName        - layout field name filter on which
// should be set, ComparisonKind   - filter comparison kind, by default - Equal,
// RightValue - filter
// value, Set     - shows that it is required to set filter
//
Procedure ChangeListFilterElement(List, FieldName, RightValue = Undefined, Set = False, ComparisonType = Undefined, FilterByPeriod = False, QuickAccess = False) Export
	
	SetElements = List.SettingsComposer.Settings.Filter;
	CommonClientServer.ChangeFilterItems(SetElements,FieldName,,RightValue,ComparisonType,Set);
	
EndProcedure

#Region BusinessPulse

Function PreviousFloatingPeriod(Period) Export
	
	If TypeOf(Period) = Type("Structure") 
		AND Period.Variant = "Last7Days" Then
		#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
			StartDate = BegOfDay(CurrentSessionDate());
		#Else
			StartDate = BegOfDay(CommonClient.SessionDate());
		#EndIf
		Return New StandardPeriod(StartDate - 14 * 86400, StartDate - 7 * 86400 - 1); 
	ElsIf Period.Variant = StandardPeriodVariant.Today Then
		Return New StandardPeriod(StandardPeriodVariant.Yesterday);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisWeek Then
		Return New StandardPeriod(StandardPeriodVariant.LastWeekTillSameWeekDay);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisMonth Then
		Return New StandardPeriod(StandardPeriodVariant.LastMonthTillSameDate);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisQuarter Then
		Return New StandardPeriod(StandardPeriodVariant.LastQuarterTillSameDate);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisHalfYear Then
		Return New StandardPeriod(StandardPeriodVariant.LastHalfYearTillSameDate);
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisYear Then
		Return New StandardPeriod(StandardPeriodVariant.LastYearTillSameDate);
	Else
		SecondsCount = (EndOfDay(Period.EndDate) - Period.StartDate + 1);
		Return New StandardPeriod(Period.StartDate - SecondsCount, Period.StartDate - 1); 
	EndIf; 
	
EndFunction
 
Function SamePeriodOfLastYear(Period) Export
	
	If TypeOf(Period) = Type("Structure")
		AND Period.Variant = "Last7Days" Then
		#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
			StartDate	= BegOfDay(CurrentSessionDate()) - 7 * 86400;
			EndDate		= BegOfDay(CurrentSessionDate()) - 1;
		#Else
			StartDate	= BegOfDay(CommonClient.SessionDate()) - 7 * 86400;
			EndDate		= BegOfDay(CommonClient.SessionDate()) - 1;
		#EndIf
	Else
		StartDate	= Period.StartDate;
		EndDate		= Period.EndDate;
	EndIf;
	
	Year	= Year(StartDate);
	Month	= Month(StartDate);
	Day		= Day(StartDate);
	
	If Year % 4 = 0 AND Month = 2 AND Day = 29 Then
		Day = 28;
	ElsIf (Year - 1) % 4 = 0 AND Month = 2 AND Day = 28 Then
		Day = 29;
	EndIf; 
	
	YearEnd		= Year(EndDate);
	MonthEndClosing	= Month(EndDate);
	DayEnd		= Day(EndDate);
	
	If YearEnd % 4 > 0 AND MonthEndClosing = 2 AND DayEnd = 29 Then
		DayEnd = 28;
	ElsIf (YearEnd - 1) % 4 = 0 AND MonthEndClosing = 2 AND DayEnd = 28 Then
		DayEnd = 29;
	EndIf; 
	
	If Period.Variant = StandardPeriodVariant.Today Then
		Date = Date(Year - 1, Month, Day);
		Return New StandardPeriod(BegOfDay(Date), EndOfDay(Date));
	ElsIf Period.Variant=StandardPeriodVariant.FromBeginningOfThisWeek Then
		
		SecondsCount	= BegOfDay(EndDate) - BegOfWeek(EndDate);
		Week			= WeekOfYear(StartDate);
		WeekDay			= WeekDay(Date(Year - 1, 1, 1));
		DayNumber		= 7 * (Week - 1) - WeekDay + 1;
		Date			= Date(Year - 1, 1, 1) + DayNumber * 86400;
		
		Return New StandardPeriod(BegOfWeek(Date), EndOfDay(Date + SecondsCount));
		
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisMonth Then
		Return New StandardPeriod(Date(Year - 1, Month, 1), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisQuarter Then
		Date = AddMonth(Date(Year - 1, 1, 1), Month - 1);
		Return New StandardPeriod(BegOfQuarter(Date), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisHalfYear Then
		
		If Month < 7 Then
			Return New StandardPeriod(Date(Year - 1, 1, 1), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
		Else
			Return New StandardPeriod(AddMonth(Date(Year - 1, 1, 1), 6), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
		EndIf;
		
	ElsIf Period.Variant = StandardPeriodVariant.FromBeginningOfThisYear Then
		Return New StandardPeriod(Date(Year - 1, 1, 1), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
	Else
		Return New StandardPeriod(Date(Year - 1, Month, Day), EndOfDay(Date(YearEnd - 1, MonthEndClosing, DayEnd)));
	EndIf; 
	
EndFunction

Function Last7DaysExceptForCurrentDay() Export
	
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		StartDate = BegOfDay(CurrentSessionDate());
	#Else
		StartDate = BegOfDay(CommonClient.SessionDate());
	#EndIf
	
	Return New StandardPeriod(StartDate - 7 * 86400, StartDate - 1); 
	
EndFunction

#EndRegion

#EndRegion
