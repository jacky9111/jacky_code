stk.v.12.0
WrittenBy    STK_v12.4.0
BEGIN Scenario
    Name		 Scenario

    BEGIN Epoch

        Epoch		 16 Dec 2025 12:10:03.000000000
        SmartEpoch		
        BEGIN EVENT
            Epoch		 16 Dec 2025 12:10:03.000000000
            EventEpoch		
            BEGIN EVENT
                Type		 EVENT_LINKTO
                Name		 AnalysisStartTime
            END EVENT
            EpochState		 Implicit
        END EVENT


    END Epoch

    BEGIN Interval

        Start		 16 Dec 2025 12:10:03.000000000
        Stop		 17 Dec 2025 12:10:03.000000000
        SmartInterval		
        BEGIN EVENTINTERVAL
            BEGIN Interval
                Start		 16 Dec 2025 12:10:03.000000000
                Stop		 17 Dec 2025 12:10:03.000000000
            END Interval
            IntervalState		 Explicit
        END EVENTINTERVAL

        EpochUsesAnalStart		 No
        AnimStartUsesAnalStart		 Yes
        AnimStopUsesAnalStop		 Yes

    END Interval

    BEGIN EOPFile

        InheritEOPSource		 No
        EOPFilename		 EOP-v1.1.txt

    END EOPFile

    BEGIN GlobalPrefs
        SatelliteNoOrbWarning		 No
        MissilePerigeeWarning		 No
        MissileStopTimeWarning		 No
        AircraftWGS84Warning		 Always
    END GlobalPrefs

    BEGIN CentralBody

        PrimaryBody		 Earth

    END CentralBody

    BEGIN CentralBodyTerrain

        BEGIN CentralBody
            Name		 Earth
            UseTerrainCache		 Yes
            TotalCacheSize		 402653184

            BEGIN StreamingTerrain
                UseCurrentStreamingTerrainServer		 Yes
                CurrentStreamingTerrainServerName		 http://twsusecovacc01.agi.com/stk-terrain/
                StreamingTerrainTilesetName		 world
                StreamingTerrainServerName		 assets.agi.com/stk-terrain/
                StreamingTerrainAzimuthElevationMaskEnabled		 No
                StreamingTerrainObscurationEnabled		 No
                StreamingTerrainCoverageGridObscurationEnabled		 No
            END StreamingTerrain
        END CentralBody

    END CentralBodyTerrain

    BEGIN StarCollection

        Name		 Hipparcos 2 Mag 8

    END StarCollection

    BEGIN ScenarioLicenses
        Module		 stk_mission_airv12.4
        Module		 stk_mission_level1v12.4
        Module		 stk_mission_level2v12.4
        Module		 stk_mission_spacev12.4
    END ScenarioLicenses

    BEGIN QuickReports
    END QuickReports

    BEGIN Extensions

        BEGIN ClsApp
            RangeConstraint		 5000
            ApoPeriPad		 30000
            OrbitPathPad		 100000
            TimeDistPad		 30000
            OutOfDate		 2592000
            MaxApoPeriStep		 900
            ApoPeriAngle		 0.7853981633974483
            UseApogeePerigeeFilter		 Yes
            UsePathFilter		 No
            UseTimeFilter		 No
            UseOutOfDate		 Yes
            CreateSats		 No
            MaxSatsToCreate		 500
            UseModelScale		 No
            ModelScale		 0
            UseCrossRefDb		 Yes
            CollisionDB		 stkAllTLE.tce
            CollisionCrossRefDB		 stkAllTLE.sd
            ShowLine		 Yes
            AnimHighlight		 Yes
            StaticHighlight		 Yes
            UseLaunchWindow		 No
            LaunchWindowUseEntireTraj		 Yes
            LaunchWindowTrajMETStart		 0
            LaunchWindowTrajMETStop		 900
            LaunchWindowStart		 8092197
            LaunchWindowStop		 8178597
            LaunchMETOffset		 0
            LaunchWindowUseSecEphem		 No 
            LaunchWindowUseScenFolderForSecEphem		 Yes
            LaunchWindowUsePrimEphem		 No 
            LaunchWindowUseScenFolderForPrimEphem		 Yes
            LaunchWindowIntervalPtr		
            BEGIN EVENTINTERVAL
                BEGIN Interval
                    Start		 20 Mar 2026 04:00:00.000000000
                    Stop		 21 Mar 2026 04:00:00.000000000
                END Interval
                IntervalState		 Explicit
            END EVENTINTERVAL

            LaunchWindowUsePrimMTO		 No 
            GroupLaunches		 No 
            LWTimeConvergence		 0.001
            LWRelValueConvergence		 1e-08
            LWTSRTimeConvergence		 0.0001
            LWTSRRelValueConvergence		 1e-10
            LaunchWindowStep		 300
            MaxTSRStep		  1.8000000000000000e+02
            MaxTSRRelMotion		  2.0000000000000000e+01
            UseLaunchArea		 No 
            LaunchAreaOrientation		 North
            LaunchAreaAzimuth		 0
            LaunchAreaXLimits		 -10000 10000
            LaunchAreaYLimits		 -10000 10000
            LaunchAreaNumXIntrPnts		 1
            LaunchAreaNumYIntrPnts		 1
            LaunchAreaAltReference		 Ellipsoid
            TargetSameStop		 No 
            SkipSurfaceMetric		 No 
            LWAreaTSRRelValueConvergence		 1e-10
            AreaLaunchWindowStep		 300
            AreaMaxTSRStep		  3.0000000000000000e+01
            AreaMaxTSRRelMotion		 1
            ShowLaunchArea		 No 
            ShowBlackoutTracks		 No 
            ShowClearedTracks		 No 
            UseObjectForClearedColor		 No 
            BlackoutColor		 #ff0000
            ClearedColor		 #ffffff
            ShowTracksSegments		 No 
            ShowMinRangeTracks		 No 
            MinRangeTrackTimeStep		 0.5
            UsePrimStepForTracks		 Yes
            GfxTracksTimeStep		 30
            GfxAreaNumXIntrPnts		 1
            GfxAreaNumYIntrPnts		 1
            CreateLaunchMTO		 No 
            CovarianceSigmaScale		 3
            CovarianceMode		 None 
        END ClsApp

        BEGIN Units
            DistanceUnit		 Kilometers
            TimeUnit		 Seconds
            DateFormat		 GregorianUTC
            AngleUnit		 Degrees
            MassUnit		 Kilograms
            PowerUnit		 dBW
            FrequencyUnit		 Gigahertz
            SmallDistanceUnit		 Meters
            LatitudeUnit		 Degrees
            LongitudeUnit		 Degrees
            DurationUnit		 Hr:Min:Sec
            Temperature		 Kelvin
            SmallTimeUnit		 Seconds
            RatioUnit		 Decibel
            RcsUnit		 Decibel
            DopplerVelocityUnit		 MetersperSecond
            SARTimeResProdUnit		 Meter-Second
            ForceUnit		 Newtons
            PressureUnit		 Pascals
            SpecificImpulseUnit		 Seconds
            PRFUnit		 Kilohertz
            BandwidthUnit		 Megahertz
            SmallVelocityUnit		 CentimetersperSecond
            Percent		 Percentage
            AviatorDistanceUnit		 NauticalMiles
            AviatorTimeUnit		 Hours
            AviatorAltitudeUnit		 Feet
            AviatorFuelQuantityUnit		 Pounds
            AviatorRunwayLengthUnit		 Kilofeet
            AviatorBearingAngleUnit		 Degrees
            AviatorAngleOfAttackUnit		 Degrees
            AviatorAttitudeAngleUnit		 Degrees
            AviatorGUnit		 StandardSeaLevelG
            SolidAngle		 Steradians
            AviatorTSFCUnit		 TSFCLbmHrLbf
            AviatorPSFCUnit		 PSFCLbmHrHp
            AviatorForceUnit		 Pounds
            AviatorPowerUnit		 Horsepower
            SpectralBandwidthUnit		 Hertz
            AviatorAltTimeUnit		 Minutes
            AviatorSmallTimeUnit		 Seconds
            AviatorEnergyUnit		 kilowatt-hours
            BitsUnit		 MegaBits
            MagneticFieldUnit		 nanoTesla
            VoltageUnit		 Volts
        END Units

        BEGIN ReportUnits
            DistanceUnit		 Kilometers
            TimeUnit		 Seconds
            DateFormat		 GregorianUTC
            AngleUnit		 Degrees
            MassUnit		 Kilograms
            PowerUnit		 dBW
            FrequencyUnit		 Gigahertz
            SmallDistanceUnit		 Meters
            LatitudeUnit		 Degrees
            LongitudeUnit		 Degrees
            DurationUnit		 Hr:Min:Sec
            Temperature		 Kelvin
            SmallTimeUnit		 Seconds
            RatioUnit		 Decibel
            RcsUnit		 Decibel
            DopplerVelocityUnit		 MetersperSecond
            SARTimeResProdUnit		 Meter-Second
            ForceUnit		 Newtons
            PressureUnit		 Pascals
            SpecificImpulseUnit		 Seconds
            PRFUnit		 Kilohertz
            BandwidthUnit		 Megahertz
            SmallVelocityUnit		 CentimetersperSecond
            Percent		 Percentage
            AviatorDistanceUnit		 NauticalMiles
            AviatorTimeUnit		 Hours
            AviatorAltitudeUnit		 Feet
            AviatorFuelQuantityUnit		 Pounds
            AviatorRunwayLengthUnit		 Kilofeet
            AviatorBearingAngleUnit		 Degrees
            AviatorAngleOfAttackUnit		 Degrees
            AviatorAttitudeAngleUnit		 Degrees
            AviatorGUnit		 StandardSeaLevelG
            SolidAngle		 Steradians
            AviatorTSFCUnit		 TSFCLbmHrLbf
            AviatorPSFCUnit		 PSFCLbmHrHp
            AviatorForceUnit		 Pounds
            AviatorPowerUnit		 Horsepower
            SpectralBandwidthUnit		 Hertz
            AviatorAltTimeUnit		 Minutes
            AviatorSmallTimeUnit		 Seconds
            AviatorEnergyUnit		 kilowatt-hours
            BitsUnit		 MegaBits
            MagneticFieldUnit		 nanoTesla
            VoltageUnit		 Volts
        END ReportUnits

        BEGIN ConnectReportUnits
            DistanceUnit		 Kilometers
            TimeUnit		 Seconds
            DateFormat		 GregorianUTC
            AngleUnit		 Degrees
            MassUnit		 Kilograms
            PowerUnit		 dBW
            FrequencyUnit		 Gigahertz
            SmallDistanceUnit		 Meters
            LatitudeUnit		 Degrees
            LongitudeUnit		 Degrees
            DurationUnit		 Hr:Min:Sec
            Temperature		 Kelvin
            SmallTimeUnit		 Seconds
            RatioUnit		 Decibel
            RcsUnit		 Decibel
            DopplerVelocityUnit		 MetersperSecond
            SARTimeResProdUnit		 Meter-Second
            ForceUnit		 Newtons
            PressureUnit		 Pascals
            SpecificImpulseUnit		 Seconds
            PRFUnit		 Kilohertz
            BandwidthUnit		 Megahertz
            SmallVelocityUnit		 CentimetersperSecond
            Percent		 Percentage
            AviatorDistanceUnit		 NauticalMiles
            AviatorTimeUnit		 Hours
            AviatorAltitudeUnit		 Feet
            AviatorFuelQuantityUnit		 Pounds
            AviatorRunwayLengthUnit		 Kilofeet
            AviatorBearingAngleUnit		 Degrees
            AviatorAngleOfAttackUnit		 Degrees
            AviatorAttitudeAngleUnit		 Degrees
            AviatorGUnit		 StandardSeaLevelG
            SolidAngle		 Steradians
            AviatorTSFCUnit		 TSFCLbmHrLbf
            AviatorPSFCUnit		 PSFCLbmHrHp
            AviatorForceUnit		 Pounds
            AviatorPowerUnit		 Horsepower
            SpectralBandwidthUnit		 Hertz
            AviatorAltTimeUnit		 Minutes
            AviatorSmallTimeUnit		 Seconds
            AviatorEnergyUnit		 kilowatt-hours
            BitsUnit		 MegaBits
            MagneticFieldUnit		 nanoTesla
            VoltageUnit		 Volts
        END ConnectReportUnits

        BEGIN ReportFavorites
            BEGIN Class
                Name		 Satellite
                BEGIN Favorite
                    Type		 Report
                    BaseDir		 Install
                    Style		 LLA Position
                END Favorite
                BEGIN Favorite
                    Type		 Report
                    BaseDir		 Install
                    Style		 Lighting Times
                END Favorite
                BEGIN Favorite
                    Type		 Graph
                    BaseDir		 Install
                    Style		 Lighting Times
                END Favorite
            END Class
        END ReportFavorites

        BEGIN ADFFileData
        END ADFFileData

        BEGIN GenDb

            BEGIN Database
                DbType		 Satellite
                DefDb		 stkAllTLE.sd
                UseMyDb		 Off
                MaxMatches		 2000
                Use4SOC		 On

                BEGIN FieldDefaults

                    BEGIN Field
                        Name		 "SSC Number"
                        Default		 "*"
                    END Field

                    BEGIN Field
                        Name		 "Common Name"
                        Default		 "*"
                    END Field

                END FieldDefaults

            END Database

            BEGIN Database
                DbType		 City
                DefDb		 stkCityDb.cd
                UseMyDb		 Off
                MaxMatches		 2000
                Use4SOC		 On

                BEGIN FieldDefaults

                    BEGIN Field
                        Name		 "City Name"
                        Default		 "*"
                    END Field

                END FieldDefaults

            END Database

            BEGIN Database
                DbType		 Facility
                DefDb		 stkFacility.fd
                UseMyDb		 Off
                MaxMatches		 2000
                Use4SOC		 On

                BEGIN FieldDefaults

                END FieldDefaults

            END Database
        END GenDb

        BEGIN SOCDb
            BEGIN Defaults
            END Defaults
        END SOCDb

        BEGIN Msgp4Ext
        END Msgp4Ext

        BEGIN FileLocations
        END FileLocations

        BEGIN Author
            Optimize		 No
            UseBasicGlobe		 No
            SaveEphemeris		 Yes
            SaveScenFolder		 No
            BEGIN ExternalFileTypes
                BEGIN Type
                    FileType		 Calculation Scalar
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Celestial Image
                    Include		 No
                END Type
                BEGIN Type
                    FileType		 Cloud
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 EOP
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 External Vector Data
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Globe
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Globe Data
                    Include		 No
                END Type
                BEGIN Type
                    FileType		 Map
                    Include		 No
                END Type
                BEGIN Type
                    FileType		 Map Image
                    Include		 No
                END Type
                BEGIN Type
                    FileType		 Marker/Label
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Model
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Object Break-up File
                    Include		 No
                END Type
                BEGIN Type
                    FileType		 Planetary Ephemeris
                    Include		 No
                END Type
                BEGIN Type
                    FileType		 Python Script
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Report Style Script
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Report/Graph Style
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Scalar Calculation File
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Terrain
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Volume Grid Intervals File
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 Volumetric File
                    Include		 Yes
                END Type
                BEGIN Type
                    FileType		 WTM
                    Include		 Yes
                END Type
            END ExternalFileTypes
            ReadOnly		 No
            ViewerPassword		 No
            STKPassword		 No
            ExcludeInstallFiles		 No
            BEGIN ExternalFileList
            END ExternalFileList
        END Author

        BEGIN ExportDataFile
            FileType		 Ephemeris
            IntervalType		 Ephemeris
            TimePeriodStart		 0
            TimePeriodStop		 0
            StepType		 Ephemeris
            StepSize		 60
            EphemType		 STK
            UseVehicleCentralBody		 Yes
            CentralBody		 Earth
            SatelliteID		 -200000
            CoordSys		 ICRF
            NonSatCoordSys		 Fixed
            InterpolateBoundaries		 Yes
            EphemFormat		 Current
            InterpType		 9
            InterpOrder		 5
            AttCoordSys		 Fixed
            Quaternions		 0
            ExportCovar		 Position
            AttitudeFormat		 Current
            TimePrecision		 6
            CCSDSDateFormat		 YMD
            CCSDSEphFormat		 SciNotation
            CCSDSTimeSystem		 UTC
            CCSDSRefFrame		 ICRF
            UseSatCenterAndFrame		 No
            IncludeCovariance		 No
            IncludeAcceleration		 No
            CCSDSFileFormat		 KVN
        END ExportDataFile

        BEGIN Desc
        END Desc

        BEGIN RfEnv
<?xml version = "1.0" standalone = "yes"?>
<SCOPE>
    <VAR name = "PropagationChannel">
        <SCOPE>
            <VAR name = "UseITU618Section2p5">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "UseCloudFogModel">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "CloudFogModel">
                <SCOPE Class = "LinkEmbedControl">
                    <VAR name = "ReferenceType">
                        <STRING>&quot;Unlinked&quot;</STRING>
                    </VAR>
                    <VAR name = "Component">
                        <VAR name = "ITU-R_P840-7">
                            <SCOPE Class = "CloudFogLossModel">
                                <VAR name = "Version">
                                    <STRING>&quot;1.0.0 a&quot;</STRING>
                                </VAR>
                                <VAR name = "IdentifierInformation">
                                    <SCOPE>
                                        <VAR name = "Identifier">
                                            <STRING>&quot;{CE9CF1BC-ABDA-4DE2-9547-CE3A471AA09C}&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Version">
                                            <STRING>&quot;1&quot;</STRING>
                                        </VAR>
                                        <VAR name = "SdfInformation">
                                            <SCOPE>
                                                <VAR name = "Version">
                                                    <STRING>&quot;0.0&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Url">
                                                    <STRING>&quot;&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                        <VAR name = "SourceIdentifierInformation">
                                            <SCOPE>
                                                <VAR name = "Identifier">
                                                    <STRING>&quot;{E7BA4392-37BE-4446-A5C7-6068165B166A}&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Version">
                                                    <STRING>&quot;1&quot;</STRING>
                                                </VAR>
                                                <VAR name = "SdfInformation">
                                                    <SCOPE>
                                                        <VAR name = "Version">
                                                            <STRING>&quot;0.0&quot;</STRING>
                                                        </VAR>
                                                        <VAR name = "Url">
                                                            <STRING>&quot;&quot;</STRING>
                                                        </VAR>
                                                    </SCOPE>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                                <VAR name = "ComponentName">
                                    <STRING>&quot;ITU-R_P840-7&quot;</STRING>
                                </VAR>
                                <VAR name = "Description">
                                    <STRING>&quot;ITU-R P840-7&quot;</STRING>
                                </VAR>
                                <VAR name = "Type">
                                    <STRING>&quot;ITU-R P840-7&quot;</STRING>
                                </VAR>
                                <VAR name = "UserComment">
                                    <STRING>&quot;ITU-R P840-7&quot;</STRING>
                                </VAR>
                                <VAR name = "ReadOnly">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "Clonable">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "Category">
                                    <STRING>&quot;@Top&quot;</STRING>
                                </VAR>
                                <VAR name = "LiquidWaterDensityValueChoice">
                                    <STRING>&quot;Liquid Water Content Density Value&quot;</STRING>
                                </VAR>
                                <VAR name = "CloudCeiling">
                                    <QUANTITY Dimension = "DistanceUnit" Unit = "m">
                                        <REAL>3000</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "CloudLayerThickness">
                                    <QUANTITY Dimension = "DistanceUnit" Unit = "m">
                                        <REAL>500</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "CloudTemp">
                                    <QUANTITY Dimension = "Temperature" Unit = "K">
                                        <REAL>273.15</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "CloudLiqWaterDensity">
                                    <QUANTITY Dimension = "SmallDensity" Unit = "kg*m^-3">
                                        <REAL>0.0001</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "AnnualAveragePercentValue">
                                    <QUANTITY Dimension = "Percent" Unit = "unitValue">
                                        <REAL>0.01</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "MonthlyAveragePercentValue">
                                    <QUANTITY Dimension = "Percent" Unit = "unitValue">
                                        <REAL>0.01</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "LiqWaterAverageDataMonth">
                                    <INT>1</INT>
                                </VAR>
                                <VAR name = "UseRainHeightAsCloudThickness">
                                    <BOOL>false</BOOL>
                                </VAR>
                            </SCOPE>
                        </VAR>
                    </VAR>
                </SCOPE>
            </VAR>
            <VAR name = "UseTropoScintModel">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "TropoScintModel">
                <SCOPE Class = "LinkEmbedControl">
                    <VAR name = "ReferenceType">
                        <STRING>&quot;Unlinked&quot;</STRING>
                    </VAR>
                    <VAR name = "Component">
                        <VAR name = "ITU-R_P618-12">
                            <SCOPE Class = "TropoScintLossModel">
                                <VAR name = "Version">
                                    <STRING>&quot;1.0.0 a&quot;</STRING>
                                </VAR>
                                <VAR name = "IdentifierInformation">
                                    <SCOPE>
                                        <VAR name = "Identifier">
                                            <STRING>&quot;{2467C2A2-5E44-4486-A500-37B3922580D9}&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Version">
                                            <STRING>&quot;1&quot;</STRING>
                                        </VAR>
                                        <VAR name = "SdfInformation">
                                            <SCOPE>
                                                <VAR name = "Version">
                                                    <STRING>&quot;0.0&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Url">
                                                    <STRING>&quot;&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                        <VAR name = "SourceIdentifierInformation">
                                            <SCOPE>
                                                <VAR name = "Identifier">
                                                    <STRING>&quot;{BC27045B-5A54-458E-BF17-702BCFE40CA8}&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Version">
                                                    <STRING>&quot;1&quot;</STRING>
                                                </VAR>
                                                <VAR name = "SdfInformation">
                                                    <SCOPE>
                                                        <VAR name = "Version">
                                                            <STRING>&quot;0.0&quot;</STRING>
                                                        </VAR>
                                                        <VAR name = "Url">
                                                            <STRING>&quot;&quot;</STRING>
                                                        </VAR>
                                                    </SCOPE>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                                <VAR name = "ComponentName">
                                    <STRING>&quot;ITU-R_P618-12&quot;</STRING>
                                </VAR>
                                <VAR name = "Description">
                                    <STRING>&quot;ITU-R P618-12&quot;</STRING>
                                </VAR>
                                <VAR name = "Type">
                                    <STRING>&quot;ITU-R P618-12&quot;</STRING>
                                </VAR>
                                <VAR name = "UserComment">
                                    <STRING>&quot;ITU-R P618-12&quot;</STRING>
                                </VAR>
                                <VAR name = "ReadOnly">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "Clonable">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "Category">
                                    <STRING>&quot;@Top&quot;</STRING>
                                </VAR>
                                <VAR name = "FadeDepthAverageTimeChoice">
                                    <STRING>&quot;Fade depth for the average year&quot;</STRING>
                                </VAR>
                                <VAR name = "ComputeDeepFade">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "FadeOutage">
                                    <QUANTITY Dimension = "Percent" Unit = "unitValue">
                                        <REAL>0.001</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "PercentTimeRefracGrad">
                                    <QUANTITY Dimension = "Percent" Unit = "unitValue">
                                        <REAL>0.1</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "SurfaceTemperature">
                                    <QUANTITY Dimension = "Temperature" Unit = "K">
                                        <REAL>273.15</REAL>
                                    </QUANTITY>
                                </VAR>
                            </SCOPE>
                        </VAR>
                    </VAR>
                </SCOPE>
            </VAR>
            <VAR name = "UseIonoFadingModel">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "IonoFadingModel">
                <SCOPE Class = "LinkEmbedControl">
                    <VAR name = "ReferenceType">
                        <STRING>&quot;Unlinked&quot;</STRING>
                    </VAR>
                    <VAR name = "Component">
                        <VAR name = "ITU-R_P531-13">
                            <SCOPE Class = "IonoFadingLossModel">
                                <VAR name = "Version">
                                    <STRING>&quot;1.0.0 a&quot;</STRING>
                                </VAR>
                                <VAR name = "IdentifierInformation">
                                    <SCOPE>
                                        <VAR name = "Identifier">
                                            <STRING>&quot;{CE3110D6-4177-43A2-8ABF-2DBF9B8806B9}&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Version">
                                            <STRING>&quot;1&quot;</STRING>
                                        </VAR>
                                        <VAR name = "SdfInformation">
                                            <SCOPE>
                                                <VAR name = "Version">
                                                    <STRING>&quot;0.0&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Url">
                                                    <STRING>&quot;&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                        <VAR name = "SourceIdentifierInformation">
                                            <SCOPE>
                                                <VAR name = "Identifier">
                                                    <STRING>&quot;{1699891E-9828-41C7-ADD4-4BE20EFC34A8}&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Version">
                                                    <STRING>&quot;1&quot;</STRING>
                                                </VAR>
                                                <VAR name = "SdfInformation">
                                                    <SCOPE>
                                                        <VAR name = "Version">
                                                            <STRING>&quot;0.0&quot;</STRING>
                                                        </VAR>
                                                        <VAR name = "Url">
                                                            <STRING>&quot;&quot;</STRING>
                                                        </VAR>
                                                    </SCOPE>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                                <VAR name = "ComponentName">
                                    <STRING>&quot;ITU-R_P531-13&quot;</STRING>
                                </VAR>
                                <VAR name = "Description">
                                    <STRING>&quot;ITU-R P531-13&quot;</STRING>
                                </VAR>
                                <VAR name = "Type">
                                    <STRING>&quot;ITU-R P531-13&quot;</STRING>
                                </VAR>
                                <VAR name = "UserComment">
                                    <STRING>&quot;ITU-R P531-13&quot;</STRING>
                                </VAR>
                                <VAR name = "ReadOnly">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "Clonable">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "Category">
                                    <STRING>&quot;@Top&quot;</STRING>
                                </VAR>
                                <VAR name = "UseAlternateAPFile">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "AlternateAPDataFile">
                                    <STRING>
                                        <PROP name = "FullName">
                                            <STRING>&quot;&quot;</STRING>
                                        </PROP>&quot;&quot;</STRING>
                                </VAR>
                            </SCOPE>
                        </VAR>
                    </VAR>
                </SCOPE>
            </VAR>
            <VAR name = "UseRainModel">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "RainModel">
                <SCOPE Class = "LinkEmbedControl">
                    <VAR name = "ReferenceType">
                        <STRING>&quot;Unlinked&quot;</STRING>
                    </VAR>
                    <VAR name = "Component">
                        <VAR name = "ITU-R_P618-12">
                            <SCOPE Class = "RainLossModel">
                                <VAR name = "Version">
                                    <STRING>&quot;1.0.0 a&quot;</STRING>
                                </VAR>
                                <VAR name = "IdentifierInformation">
                                    <SCOPE>
                                        <VAR name = "Identifier">
                                            <STRING>&quot;{A65B31FD-FBC7-4A20-96E6-14E0BBB0EC07}&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Version">
                                            <STRING>&quot;1&quot;</STRING>
                                        </VAR>
                                        <VAR name = "SdfInformation">
                                            <SCOPE>
                                                <VAR name = "Version">
                                                    <STRING>&quot;0.0&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Url">
                                                    <STRING>&quot;&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                        <VAR name = "SourceIdentifierInformation">
                                            <SCOPE>
                                                <VAR name = "Identifier">
                                                    <STRING>&quot;{1113D770-D1E5-4DEF-99A3-6B3F4D5CE16A}&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Version">
                                                    <STRING>&quot;1&quot;</STRING>
                                                </VAR>
                                                <VAR name = "SdfInformation">
                                                    <SCOPE>
                                                        <VAR name = "Version">
                                                            <STRING>&quot;0.0&quot;</STRING>
                                                        </VAR>
                                                        <VAR name = "Url">
                                                            <STRING>&quot;&quot;</STRING>
                                                        </VAR>
                                                    </SCOPE>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                                <VAR name = "ComponentName">
                                    <STRING>&quot;ITU-R_P618-12&quot;</STRING>
                                </VAR>
                                <VAR name = "Description">
                                    <STRING>&quot;ITU-R P618-12 rain model&quot;</STRING>
                                </VAR>
                                <VAR name = "Type">
                                    <STRING>&quot;ITU-R P618-12&quot;</STRING>
                                </VAR>
                                <VAR name = "UserComment">
                                    <STRING>&quot;ITU-R P618-12 rain model&quot;</STRING>
                                </VAR>
                                <VAR name = "ReadOnly">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "Clonable">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "Category">
                                    <STRING>&quot;@Top&quot;</STRING>
                                </VAR>
                                <VAR name = "SurfaceTemperature">
                                    <QUANTITY Dimension = "Temperature" Unit = "K">
                                        <REAL>273.15</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "EnableDepolarizationLoss">
                                    <BOOL>false</BOOL>
                                </VAR>
                            </SCOPE>
                        </VAR>
                    </VAR>
                </SCOPE>
            </VAR>
            <VAR name = "UseAtmosAbsorptionModel">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "AtmosAbsorptionModel">
                <SCOPE Class = "LinkEmbedControl">
                    <VAR name = "ReferenceType">
                        <STRING>&quot;Unlinked&quot;</STRING>
                    </VAR>
                    <VAR name = "Component">
                        <VAR name = "ITU-R_P676-9">
                            <SCOPE Class = "AtmosphericAbsorptionModel">
                                <VAR name = "Version">
                                    <STRING>&quot;1.0.1 a&quot;</STRING>
                                </VAR>
                                <VAR name = "IdentifierInformation">
                                    <SCOPE>
                                        <VAR name = "Identifier">
                                            <STRING>&quot;{797FCA94-5098-4C55-AB32-24E98C6220D6}&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Version">
                                            <STRING>&quot;1&quot;</STRING>
                                        </VAR>
                                        <VAR name = "SdfInformation">
                                            <SCOPE>
                                                <VAR name = "Version">
                                                    <STRING>&quot;0.0&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Url">
                                                    <STRING>&quot;&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                        <VAR name = "SourceIdentifierInformation">
                                            <SCOPE>
                                                <VAR name = "Identifier">
                                                    <STRING>&quot;{5DBDF434-D4CA-44F6-8097-A6EBF681200D}&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Version">
                                                    <STRING>&quot;1&quot;</STRING>
                                                </VAR>
                                                <VAR name = "SdfInformation">
                                                    <SCOPE>
                                                        <VAR name = "Version">
                                                            <STRING>&quot;0.0&quot;</STRING>
                                                        </VAR>
                                                        <VAR name = "Url">
                                                            <STRING>&quot;&quot;</STRING>
                                                        </VAR>
                                                    </SCOPE>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                                <VAR name = "ComponentName">
                                    <STRING>&quot;ITU-R_P676-9&quot;</STRING>
                                </VAR>
                                <VAR name = "Description">
                                    <STRING>&quot;ITU-R P676-9 gaseous absorption model&quot;</STRING>
                                </VAR>
                                <VAR name = "Type">
                                    <STRING>&quot;ITU-R P676-9&quot;</STRING>
                                </VAR>
                                <VAR name = "UserComment">
                                    <STRING>&quot;ITU-R P676-9 gaseous absorption model&quot;</STRING>
                                </VAR>
                                <VAR name = "ReadOnly">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "Clonable">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "Category">
                                    <STRING>&quot;@Top&quot;</STRING>
                                </VAR>
                                <VAR name = "UseApproxMethod">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "UseSeasonalRegional">
                                    <BOOL>true</BOOL>
                                </VAR>
                            </SCOPE>
                        </VAR>
                    </VAR>
                </SCOPE>
            </VAR>
            <VAR name = "UseUrbanTerresPropLossModel">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "UrbanTerresPropLossModel">
                <SCOPE Class = "LinkEmbedControl">
                    <VAR name = "ReferenceType">
                        <STRING>&quot;Unlinked&quot;</STRING>
                    </VAR>
                    <VAR name = "Component">
                        <VAR name = "Two_Ray">
                            <SCOPE Class = "UrbanTerrestrialPropagationLossModel">
                                <VAR name = "Version">
                                    <STRING>&quot;1.0.0 a&quot;</STRING>
                                </VAR>
                                <VAR name = "IdentifierInformation">
                                    <SCOPE>
                                        <VAR name = "Identifier">
                                            <STRING>&quot;{6CAC0CF8-9EE3-4806-AF13-FC37AA5BB07B}&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Version">
                                            <STRING>&quot;1&quot;</STRING>
                                        </VAR>
                                        <VAR name = "SdfInformation">
                                            <SCOPE>
                                                <VAR name = "Version">
                                                    <STRING>&quot;0.0&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Url">
                                                    <STRING>&quot;&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                        <VAR name = "SourceIdentifierInformation">
                                            <SCOPE>
                                                <VAR name = "Identifier">
                                                    <STRING>&quot;{60FA4C9B-5D74-4743-A449-66CEB6DFC97B}&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Version">
                                                    <STRING>&quot;1&quot;</STRING>
                                                </VAR>
                                                <VAR name = "SdfInformation">
                                                    <SCOPE>
                                                        <VAR name = "Version">
                                                            <STRING>&quot;0.0&quot;</STRING>
                                                        </VAR>
                                                        <VAR name = "Url">
                                                            <STRING>&quot;&quot;</STRING>
                                                        </VAR>
                                                    </SCOPE>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                                <VAR name = "ComponentName">
                                    <STRING>&quot;Two_Ray&quot;</STRING>
                                </VAR>
                                <VAR name = "Description">
                                    <STRING>&quot;Two Ray (Fourth Power Law) atmospheric absorption model&quot;</STRING>
                                </VAR>
                                <VAR name = "Type">
                                    <STRING>&quot;Two Ray&quot;</STRING>
                                </VAR>
                                <VAR name = "UserComment">
                                    <STRING>&quot;Two Ray (Fourth Power Law) atmospheric absorption model&quot;</STRING>
                                </VAR>
                                <VAR name = "ReadOnly">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "Clonable">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "Category">
                                    <STRING>&quot;@Top&quot;</STRING>
                                </VAR>
                                <VAR name = "SurfaceTemperature">
                                    <QUANTITY Dimension = "Temperature" Unit = "K">
                                        <REAL>273.15</REAL>
                                    </QUANTITY>
                                </VAR>
                                <VAR name = "LossFactor">
                                    <REAL>1</REAL>
                                </VAR>
                            </SCOPE>
                        </VAR>
                    </VAR>
                </SCOPE>
            </VAR>
            <VAR name = "UseCustomA">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "UseCustomB">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "UseCustomC">
                <BOOL>false</BOOL>
            </VAR>
        </SCOPE>
    </VAR>
    <VAR name = "EarthTemperature">
        <QUANTITY Dimension = "Temperature" Unit = "K">
            <REAL>290</REAL>
        </QUANTITY>
    </VAR>
    <VAR name = "RainOutagePercent">
        <REAL>0.1</REAL>
    </VAR>
    <VAR name = "ActiveCommSystem">
        <LINKTOOBJ>
            <STRING>&quot;None&quot;</STRING>
        </LINKTOOBJ>
    </VAR>
    <VAR name = "MagneticNorthPoleLatitude">
        <QUANTITY Dimension = "AngleUnit" Unit = "rad">
            <REAL>1.387536755335492</REAL>
        </QUANTITY>
    </VAR>
    <VAR name = "MagneticNorthPoleLongitude">
        <QUANTITY Dimension = "AngleUnit" Unit = "rad">
            <REAL>-1.204277183876087</REAL>
        </QUANTITY>
    </VAR>
</SCOPE>        END RfEnv

        BEGIN LaserEnv
<?xml version = "1.0" standalone = "yes"?>
<SCOPE>
    <VAR name = "PropagationChannel">
        <SCOPE>
            <VAR name = "EnableAtmosphericLossModel">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "AtmosphericLossModel">
                <SCOPE Class = "LinkEmbedControl">
                    <VAR name = "ReferenceType">
                        <STRING>&quot;Unlinked&quot;</STRING>
                    </VAR>
                    <VAR name = "Component">
                        <VAR name = "Beer-Bouguer-Lambert_Law">
                            <SCOPE Class = "LaserAtmosphericAbsorptionLossModel">
                                <VAR name = "Version">
                                    <STRING>&quot;1.0.0 a&quot;</STRING>
                                </VAR>
                                <VAR name = "IdentifierInformation">
                                    <SCOPE>
                                        <VAR name = "Identifier">
                                            <STRING>&quot;{ADE9A75D-6B5C-44CB-B12C-5547F01C42C6}&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Version">
                                            <STRING>&quot;1&quot;</STRING>
                                        </VAR>
                                        <VAR name = "SdfInformation">
                                            <SCOPE>
                                                <VAR name = "Version">
                                                    <STRING>&quot;0.0&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Url">
                                                    <STRING>&quot;&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                        <VAR name = "SourceIdentifierInformation">
                                            <SCOPE>
                                                <VAR name = "Identifier">
                                                    <STRING>&quot;{6896684B-630D-472D-8027-385684842E74}&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Version">
                                                    <STRING>&quot;1&quot;</STRING>
                                                </VAR>
                                                <VAR name = "SdfInformation">
                                                    <SCOPE>
                                                        <VAR name = "Version">
                                                            <STRING>&quot;0.0&quot;</STRING>
                                                        </VAR>
                                                        <VAR name = "Url">
                                                            <STRING>&quot;&quot;</STRING>
                                                        </VAR>
                                                    </SCOPE>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                                <VAR name = "ComponentName">
                                    <STRING>&quot;Beer-Bouguer-Lambert_Law&quot;</STRING>
                                </VAR>
                                <VAR name = "Description">
                                    <STRING>&quot;Model atmospheric loss for laser receivers using the Beer-Bouguer-Lambert Law&quot;</STRING>
                                </VAR>
                                <VAR name = "Type">
                                    <STRING>&quot;Beer-Bouguer-Lambert Law&quot;</STRING>
                                </VAR>
                                <VAR name = "UserComment">
                                    <STRING>&quot;Model atmospheric loss for laser receivers using the Beer-Bouguer-Lambert Law&quot;</STRING>
                                </VAR>
                                <VAR name = "ReadOnly">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "Clonable">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "Category">
                                    <STRING>&quot;@Top&quot;</STRING>
                                </VAR>
                                <VAR name = "LayerList">
                                    <LIST>
                                        <SCOPE>
                                            <VAR name = "LayerNum">
                                                <INT>1</INT>
                                            </VAR>
                                            <VAR name = "LayerTop">
                                                <QUANTITY Dimension = "DistanceUnit" Unit = "m">
                                                    <REAL>100000</REAL>
                                                </QUANTITY>
                                            </VAR>
                                            <VAR name = "ExtinctionCoefficient">
                                                <QUANTITY Dimension = "UnitlessPerSmallDistance" Unit = "m^-1">
                                                    <REAL>0</REAL>
                                                </QUANTITY>
                                            </VAR>
                                        </SCOPE>
                                    </LIST>
                                </VAR>
                                <VAR name = "EnableEvenlySpacedHeights">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "MaxLayerHeight">
                                    <QUANTITY Dimension = "DistanceUnit" Unit = "m">
                                        <REAL>100000</REAL>
                                    </QUANTITY>
                                </VAR>
                            </SCOPE>
                        </VAR>
                    </VAR>
                </SCOPE>
            </VAR>
            <VAR name = "EnableTropoScintLossModel">
                <BOOL>false</BOOL>
            </VAR>
            <VAR name = "TropoScintLossModel">
                <SCOPE Class = "LinkEmbedControl">
                    <VAR name = "ReferenceType">
                        <STRING>&quot;Unlinked&quot;</STRING>
                    </VAR>
                    <VAR name = "Component">
                        <VAR name = "ITU-R_P1814">
                            <SCOPE Class = "LaserTropoScintLossModel">
                                <VAR name = "Version">
                                    <STRING>&quot;1.0.0 a&quot;</STRING>
                                </VAR>
                                <VAR name = "IdentifierInformation">
                                    <SCOPE>
                                        <VAR name = "Identifier">
                                            <STRING>&quot;{C2B5D832-04FE-416D-B47A-27A8D5C81CD9}&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Version">
                                            <STRING>&quot;1&quot;</STRING>
                                        </VAR>
                                        <VAR name = "SdfInformation">
                                            <SCOPE>
                                                <VAR name = "Version">
                                                    <STRING>&quot;0.0&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Url">
                                                    <STRING>&quot;&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                        <VAR name = "SourceIdentifierInformation">
                                            <SCOPE>
                                                <VAR name = "Identifier">
                                                    <STRING>&quot;{651AF2C8-7D6D-457E-8F99-1FB796A460BF}&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Version">
                                                    <STRING>&quot;1&quot;</STRING>
                                                </VAR>
                                                <VAR name = "SdfInformation">
                                                    <SCOPE>
                                                        <VAR name = "Version">
                                                            <STRING>&quot;0.0&quot;</STRING>
                                                        </VAR>
                                                        <VAR name = "Url">
                                                            <STRING>&quot;&quot;</STRING>
                                                        </VAR>
                                                    </SCOPE>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                                <VAR name = "ComponentName">
                                    <STRING>&quot;ITU-R_P1814&quot;</STRING>
                                </VAR>
                                <VAR name = "Description">
                                    <STRING>&quot;ITU-R P1814&quot;</STRING>
                                </VAR>
                                <VAR name = "Type">
                                    <STRING>&quot;ITU-R P1814&quot;</STRING>
                                </VAR>
                                <VAR name = "UserComment">
                                    <STRING>&quot;ITU-R P1814&quot;</STRING>
                                </VAR>
                                <VAR name = "ReadOnly">
                                    <BOOL>false</BOOL>
                                </VAR>
                                <VAR name = "Clonable">
                                    <BOOL>true</BOOL>
                                </VAR>
                                <VAR name = "Category">
                                    <STRING>&quot;@Top&quot;</STRING>
                                </VAR>
                                <VAR name = "AtmosphericTurbulenceModel">
                                    <VAR name = "Constant">
                                        <SCOPE Class = "AtmosphericTurbulenceModel">
                                            <VAR name = "ConstantRefractiveIndexStructureParameter">
                                                <REAL>1.7e-14</REAL>
                                            </VAR>
                                            <VAR name = "Type">
                                                <STRING>&quot;Constant&quot;</STRING>
                                            </VAR>
                                        </SCOPE>
                                    </VAR>
                                </VAR>
                            </SCOPE>
                        </VAR>
                    </VAR>
                </SCOPE>
            </VAR>
        </SCOPE>
    </VAR>
</SCOPE>        END LaserEnv

        BEGIN CommRad
        END CommRad

        BEGIN RadarCrossSection
<?xml version = "1.0" standalone = "yes"?>
<SCOPE>
    <VAR name = "Model">
        <SCOPE Class = "LinkEmbedControl">
            <VAR name = "ReferenceType">
                <STRING>&quot;Unlinked&quot;</STRING>
            </VAR>
            <VAR name = "Component">
                <VAR name = "Radar_Cross_Section">
                    <SCOPE Class = "RCS">
                        <VAR name = "Version">
                            <STRING>&quot;1.0.0 a&quot;</STRING>
                        </VAR>
                        <VAR name = "IdentifierInformation">
                            <SCOPE>
                                <VAR name = "Identifier">
                                    <STRING>&quot;{F3F08FD9-AC0A-4D2F-A78D-7F0ECCA717BA}&quot;</STRING>
                                </VAR>
                                <VAR name = "Version">
                                    <STRING>&quot;1&quot;</STRING>
                                </VAR>
                                <VAR name = "SdfInformation">
                                    <SCOPE>
                                        <VAR name = "Version">
                                            <STRING>&quot;0.0&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Url">
                                            <STRING>&quot;&quot;</STRING>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                                <VAR name = "SourceIdentifierInformation">
                                    <SCOPE>
                                        <VAR name = "Identifier">
                                            <STRING>&quot;{EF03E656-5AB7-4F70-A363-4753683F2BD4}&quot;</STRING>
                                        </VAR>
                                        <VAR name = "Version">
                                            <STRING>&quot;1&quot;</STRING>
                                        </VAR>
                                        <VAR name = "SdfInformation">
                                            <SCOPE>
                                                <VAR name = "Version">
                                                    <STRING>&quot;0.0&quot;</STRING>
                                                </VAR>
                                                <VAR name = "Url">
                                                    <STRING>&quot;&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </SCOPE>
                                </VAR>
                            </SCOPE>
                        </VAR>
                        <VAR name = "ComponentName">
                            <STRING>&quot;Radar_Cross_Section&quot;</STRING>
                        </VAR>
                        <VAR name = "Description">
                            <STRING>&quot;Radar Cross Section&quot;</STRING>
                        </VAR>
                        <VAR name = "Type">
                            <STRING>&quot;Radar Cross Section&quot;</STRING>
                        </VAR>
                        <VAR name = "UserComment">
                            <STRING>&quot;Radar Cross Section&quot;</STRING>
                        </VAR>
                        <VAR name = "ReadOnly">
                            <BOOL>false</BOOL>
                        </VAR>
                        <VAR name = "Clonable">
                            <BOOL>true</BOOL>
                        </VAR>
                        <VAR name = "Category">
                            <STRING>&quot;@Top&quot;</STRING>
                        </VAR>
                        <VAR name = "FrequencyBandList">
                            <LIST>
                                <SCOPE>
                                    <VAR name = "MinFrequency">
                                        <QUANTITY Dimension = "BandwidthUnit" Unit = "Hz">
                                            <REAL>2997920</REAL>
                                        </QUANTITY>
                                    </VAR>
                                    <VAR name = "ComputeTypeStrategy">
                                        <VAR name = "Constant Value">
                                            <SCOPE Class = "RCS Compute Strategy">
                                                <VAR name = "ConstantValue">
                                                    <QUANTITY Dimension = "RcsUnit" Unit = "sqm">
                                                        <REAL>1</REAL>
                                                    </QUANTITY>
                                                </VAR>
                                                <VAR name = "Type">
                                                    <STRING>&quot;Constant Value&quot;</STRING>
                                                </VAR>
                                                <VAR name = "ComponentName">
                                                    <STRING>&quot;Constant Value&quot;</STRING>
                                                </VAR>
                                            </SCOPE>
                                        </VAR>
                                    </VAR>
                                    <VAR name = "SwerlingCase">
                                        <STRING>&quot;0&quot;</STRING>
                                    </VAR>
                                </SCOPE>
                            </LIST>
                        </VAR>
                    </SCOPE>
                </VAR>
            </VAR>
        </SCOPE>
    </VAR>
</SCOPE>        END RadarCrossSection

        BEGIN RadarClutter
<?xml version = "1.0" standalone = "yes"?>
<SCOPE>
    <VAR name = "ClutterMap">
        <VAR name = "Constant Coefficient">
            <SCOPE Class = "Clutter Map">
                <VAR name = "ClutterCoefficient">
                    <QUANTITY Dimension = "RatioUnit" Unit = "units">
                        <REAL>1</REAL>
                    </QUANTITY>
                </VAR>
                <VAR name = "Type">
                    <STRING>&quot;Constant Coefficient&quot;</STRING>
                </VAR>
                <VAR name = "ComponentName">
                    <STRING>&quot;Constant Coefficient&quot;</STRING>
                </VAR>
            </SCOPE>
        </VAR>
    </VAR>
</SCOPE>        END RadarClutter

        BEGIN Gator
            RPOComponentsLoaded		 False
        END Gator

        BEGIN Crdn
        END Crdn

        BEGIN SpiceExt
            OutputErrorMsgsOnLoad		 No
            SpiceFile		 "ceres.bsp"

            SpiceFile		 "jupiter.bsp"

            SpiceFile		 "mars.bsp"

            SpiceFile		 "neptune.bsp"

            SpiceFile		 "planets.bsp"

            SpiceFile		 "pluto.bsp"

            SpiceFile		 "saturn.bsp"

            SpiceFile		 "uranus.bsp"

        END SpiceExt

        BEGIN FlightScenExt
        END FlightScenExt

        BEGIN Graphics

            BEGIN Animation

                StartTime		 16 Dec 2025 12:10:03.000000000
                EndTime		 17 Dec 2025 12:10:03.000000000
                CurrentTime		 16 Dec 2025 12:20:13.000000000
                Direction		 Forward
                UpdateDelta		 10
                RefreshDelta		 0.010000
                XRealTimeMult		 1
                RealTimeOffset		 0
                XRtStartFromPause		                Yes		
                TimeArrayIncrement		 1

            END Animation


            BEGIN DisplayFlags
                ShowLabels		 On
                ShowPassLabel		 Off
                ShowElsetNum		 Off
                ShowGndTracks		 On
                ShowGndMarkers		 On
                ShowOrbitMarkers		 On
                ShowPlanetOrbits		 Off
                ShowPlanetCBIPos		 On
                ShowPlanetCBILabel		 On
                ShowPlanetGndPos		 On
                ShowPlanetGndLabel		 On
                ShowSensors		 On
                ShowWayptMarkers		 Off
                ShowWayptTurnMarkers		 Off
                ShowOrbits		 On
                ShowDtedRegions		 Off
                ShowAreaTgtCentroids		 On
                ShowToolBar		 On
                ShowStatusBar		 On
                ShowScrollBars		 On
                AllowAnimUpdate		 On
                AccShowLine		 On
                AccAnimHigh		 On
                AccStatHigh		 On
                AccAnimLineLineWidth		  1.0000000000000000e+00
                ShowPrintButton		 On
                ShowAnimButtons		 On
                ShowAnimModeButtons		 On
                ShowZoomMsrButtons		 On
                ShowMapCbButton		 Off
            END DisplayFlags

            BEGIN WinFonts

                Consolas,12,700,0
                Consolas,14,700,0
                Consolas,16,700,0

            END WinFonts

            BEGIN MapData

                BEGIN TerrainConverterData
                    NorthLat		  0.0000000000000000e+00
                    EastLon		  0.0000000000000000e+00
                    SouthLat		  0.0000000000000000e+00
                    WestLon		  0.0000000000000000e+00
                    ColorByRGB		 No
                    AltsFromMSL		 No
                    UseColorRamp		 Yes
                    UseRegionMinMax		 Yes
                    SizeSameAsSrc		 Yes
                    MinAltHSV		  0.0000000000000000e+00  6.9999999999999996e-01  8.0000000000000004e-01  4.0000000000000002e-01
                    MaxAltHSV		  1.0000000000000000e+06  0.0000000000000000e+00  2.0000000000000001e-01  1.0000000000000000e+00
                    SmoothColors		 Yes
                    CreateChunkTrn		 No
                    OutputFormat		 PDTTX
                END TerrainConverterData

                DisableDefKbdActions		 Off
                TextShadowStyle		 Dark
                TextShadowColor		 #000000
                BingLevelOfDetailScale		 2

                BEGIN MapStyles

                    UseStyleTime		 No

                    BEGIN Style
                        Name		 DefaultWithBing
                        Time		 8092197
                        UpdateDelta		 10

                        BEGIN MapAttributes
                            PrimaryBody		 Earth
                            SecondaryBody		 Sun
                            CenterLatitude		 0
                            CenterLongitude		 0
                            ProjectionAltitude		 63621860
                            FieldOfView		 35
                            OrthoDisplayDistance		 20000000
                            TransformTrajectory		 On
                            EquatorialRadius		 6378137
                            BackgroundColor		 #000000
                            LatLonLines		 On
                            LatSpacing		 30
                            LonSpacing		 30
                            LatLonLineColor		 #999999
                            LatLonLineStyle		 2
                            ShowOrthoDistGrid		 Off
                            OrthoGridXSpacing		 5
                            OrthoGridYSpacing		 5
                            OrthoGridColor		 #ffffff
                            ShowImageExtents		 Off
                            ImageExtentLineColor		 #ffffff
                            ImageExtentLineStyle		 0
                            ImageExtentLineWidth		 1
                            ShowImageNames		 Off
                            ImageNameFont		 0
                            Projection		 EquidistantCylindrical
                            Resolution		 VeryLow
                            CoordinateSys		 ECF
                            UseBackgroundImage		 On
                            UseBingForBackground		 On
                            BingType		 Aerial
                            BingLogoHorizAlign		 Right
                            BingLogoVertAlign		 Bottom
                            BackgroundImageFile		 Basic.bmp
                            UseNightLights		 Off
                            NightLightsFactor		 3.5
                            UseCloudsFile		 Off
                            BEGIN ZoomLocations
                                BEGIN ZoomLocation
                                    CenterLat		 0
                                    CenterLon		 0
                                    ZoomWidth		 359.999998
                                    ZoomHeight		 180
                                END ZoomLocation
                            END ZoomLocations
                            UseVarAspectRatio		 No
                            SwapMapResolution		 Yes
                            NoneToVLowSwapDist		 2000000
                            VLowToLowSwapDist		 20000
                            LowToMediumSwapDist		 10000
                            MediumToHighSwapDist		 5000
                            HighToVHighSwapDist		 1000
                            VHighToSHighSwapDist		 100
                            BEGIN Axes
                                DisplayAxes		 no
                                CoordSys		 CBI
                                2aryCB		 Sun
                                Display+x		 yes
                                Label+x		 yes
                                Color+x		 #ffffff
                                Scale+x		 3
                                Display-x		 yes
                                Label-x		 yes
                                Color-x		 #ffffff
                                Scale-x		 3
                                Display+y		 yes
                                Label+y		 yes
                                Color+y		 #ffffff
                                Scale+y		 3
                                Display-y		 yes
                                Label-y		 yes
                                Color-y		 #ffffff
                                Scale-y		 3
                                Display+z		 yes
                                Label+z		 yes
                                Color+z		 #ffffff
                                Scale+z		 3
                                Display-z		 yes
                                Label-z		 yes
                                Color-z		 #ffffff
                                Scale-z		 3
                            END Axes

                        END MapAttributes

                        BEGIN MapList
                            BEGIN Detail
                                Alias		 RWDB2_Coastlines
                                Show		 Yes
                                Color		 #8fbc8f
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_International_Borders
                                Show		 No
                                Color		 #8fbc8f
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_Islands
                                Show		 No
                                Color		 #8fbc8f
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_Lakes
                                Show		 No
                                Color		 #87cefa
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_Provincial_Borders
                                Show		 No
                                Color		 #8fbc8f
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_Rivers
                                Show		 No
                                Color		 #87cefa
                            END Detail
                        END MapList


                        BEGIN MapAnnotations
                        END MapAnnotations

                        BEGIN RecordMovie
                            OutputFormat		 VIDEO
                            SdfSelected		 No
                            Directory		 D:\STK 12\Scenario1
                            BaseName		 Frame
                            Digits		 4
                            Frame		 0
                            LastAnimTime		 0
                            OutputMode		 Normal
                            HiResAssembly		 Assemble
                            HRWidth		 6000
                            HRHeight		 4500
                            HRDPI		 600
                            UseSnapInterval		 No
                            SnapInterval		 0
                            VideoCodec		 "H264"
                            Framerate		 30
                            Bitrate		 10000000
                        END RecordMovie


                        BEGIN TimeDisplay
                            Show		 0
                            TextColor		 #ffffff
                            TextTranslucency		 0
                            ShowBackground		 0
                            BackColor		 #4d4d4d
                            BackTranslucency		 0.4
                            XPosition		 20
                            YPosition		 -20
                        END TimeDisplay

                        BEGIN LightingData
                            DisplayAltitude		 0
                            SubsolarPoint		 Off
                            SubsolarPointColor		 #ffff00
                            SubsolarPointMarkerStyle		 2

                            ShowUmbraLine		 Off
                            UmbraLineColor		 #000000
                            UmbraLineStyle		 0
                            UmbraLineWidth		 2
                            FillUmbra		 On
                            UmbraFillColor		 #000000
                            ShowSunlightLine		 Off
                            SunlightLineColor		 #ffff00
                            SunlightLineStyle		 0
                            SunlightLineWidth		 2
                            FillSunlight		 On
                            SunlightFillColor		 #ffffff
                            SunlightMinOpacity		 0
                            SunlightMaxOpacity		 0.2
                            UmbraMaxOpacity		 0.7
                            UmbraMinOpacity		 0.4
                        END LightingData

                        ShowDtedRegions		 Off

                    END Style

                    BEGIN Style
                        Name		 DefaultWithoutBing
                        Time		 8092197
                        UpdateDelta		 10

                        BEGIN MapAttributes
                            PrimaryBody		 Earth
                            SecondaryBody		 Sun
                            CenterLatitude		 0
                            CenterLongitude		 0
                            ProjectionAltitude		 63621860
                            FieldOfView		 35
                            OrthoDisplayDistance		 20000000
                            TransformTrajectory		 On
                            EquatorialRadius		 6378137
                            BackgroundColor		 #000000
                            LatLonLines		 On
                            LatSpacing		 30
                            LonSpacing		 30
                            LatLonLineColor		 #999999
                            LatLonLineStyle		 2
                            ShowOrthoDistGrid		 Off
                            OrthoGridXSpacing		 5
                            OrthoGridYSpacing		 5
                            OrthoGridColor		 #ffffff
                            ShowImageExtents		 Off
                            ImageExtentLineColor		 #ffffff
                            ImageExtentLineStyle		 0
                            ImageExtentLineWidth		 1
                            ShowImageNames		 Off
                            ImageNameFont		 0
                            Projection		 EquidistantCylindrical
                            Resolution		 VeryLow
                            CoordinateSys		 ECF
                            UseBackgroundImage		 On
                            UseBingForBackground		 Off
                            BingType		 Aerial
                            BingLogoHorizAlign		 Right
                            BingLogoVertAlign		 Bottom
                            BackgroundImageFile		 Basic.bmp
                            UseNightLights		 Off
                            NightLightsFactor		 3.5
                            UseCloudsFile		 Off
                            BEGIN ZoomLocations
                                BEGIN ZoomLocation
                                    CenterLat		 0
                                    CenterLon		 0
                                    ZoomWidth		 359.999998
                                    ZoomHeight		 180
                                END ZoomLocation
                            END ZoomLocations
                            UseVarAspectRatio		 No
                            SwapMapResolution		 Yes
                            NoneToVLowSwapDist		 2000000
                            VLowToLowSwapDist		 20000
                            LowToMediumSwapDist		 10000
                            MediumToHighSwapDist		 5000
                            HighToVHighSwapDist		 1000
                            VHighToSHighSwapDist		 100
                            BEGIN Axes
                                DisplayAxes		 no
                                CoordSys		 CBI
                                2aryCB		 Sun
                                Display+x		 yes
                                Label+x		 yes
                                Color+x		 #ffffff
                                Scale+x		 3
                                Display-x		 yes
                                Label-x		 yes
                                Color-x		 #ffffff
                                Scale-x		 3
                                Display+y		 yes
                                Label+y		 yes
                                Color+y		 #ffffff
                                Scale+y		 3
                                Display-y		 yes
                                Label-y		 yes
                                Color-y		 #ffffff
                                Scale-y		 3
                                Display+z		 yes
                                Label+z		 yes
                                Color+z		 #ffffff
                                Scale+z		 3
                                Display-z		 yes
                                Label-z		 yes
                                Color-z		 #ffffff
                                Scale-z		 3
                            END Axes

                        END MapAttributes

                        BEGIN MapList
                            BEGIN Detail
                                Alias		 RWDB2_Coastlines
                                Show		 Yes
                                Color		 #8fbc8f
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_International_Borders
                                Show		 No
                                Color		 #8fbc8f
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_Islands
                                Show		 No
                                Color		 #8fbc8f
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_Lakes
                                Show		 No
                                Color		 #87cefa
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_Provincial_Borders
                                Show		 No
                                Color		 #8fbc8f
                            END Detail
                            BEGIN Detail
                                Alias		 RWDB2_Rivers
                                Show		 No
                                Color		 #87cefa
                            END Detail
                        END MapList


                        BEGIN MapAnnotations
                        END MapAnnotations

                        BEGIN RecordMovie
                            OutputFormat		 VIDEO
                            SdfSelected		 No
                            Directory		 D:\STK 12\Scenario1
                            BaseName		 Frame
                            Digits		 4
                            Frame		 0
                            LastAnimTime		 0
                            OutputMode		 Normal
                            HiResAssembly		 Assemble
                            HRWidth		 6000
                            HRHeight		 4500
                            HRDPI		 600
                            UseSnapInterval		 No
                            SnapInterval		 0
                            VideoCodec		 "H264"
                            Framerate		 30
                            Bitrate		 3000000
                        END RecordMovie


                        BEGIN TimeDisplay
                            Show		 0
                            TextColor		 #ffffff
                            TextTranslucency		 0
                            ShowBackground		 0
                            BackColor		 #4d4d4d
                            BackTranslucency		 0.4
                            XPosition		 20
                            YPosition		 -20
                        END TimeDisplay

                        BEGIN LightingData
                            DisplayAltitude		 0
                            SubsolarPoint		 Off
                            SubsolarPointColor		 #ffff00
                            SubsolarPointMarkerStyle		 2

                            ShowUmbraLine		 Off
                            UmbraLineColor		 #000000
                            UmbraLineStyle		 0
                            UmbraLineWidth		 2
                            FillUmbra		 On
                            UmbraFillColor		 #000000
                            ShowSunlightLine		 Off
                            SunlightLineColor		 #ffff00
                            SunlightLineStyle		 0
                            SunlightLineWidth		 2
                            FillSunlight		 On
                            SunlightFillColor		 #ffffff
                            SunlightMinOpacity		 0
                            SunlightMaxOpacity		 0.2
                            UmbraMaxOpacity		 0.7
                            UmbraMinOpacity		 0.4
                        END LightingData

                        ShowDtedRegions		 Off

                    END Style

                END MapStyles

            END MapData

            BEGIN GfxClassPref

            END GfxClassPref


            BEGIN ConnectGraphicsOptions

                AsyncPickReturnUnique		 OFF

            END ConnectGraphicsOptions

        END Graphics

        BEGIN Overlays
        END Overlays

        BEGIN VO
        END VO

    END Extensions

    BEGIN SubObjects

        Class Facility

            GS_01		

        END Class

        Class Satellite

            P01_S01		
            P01_S02		
            P01_S03		
            P01_S04		
            P01_S05		
            P01_S06		
            P01_S07		
            P01_S08		
            P01_S09		
            P01_S10		
            P01_S11		
            P01_S12		
            P01_S13		
            P01_S14		
            P01_S15		
            P01_S16		
            P01_S17		
            P01_S18		
            P01_S19		
            P01_S20		
            P01_S21		
            P01_S22		
            P01_S23		
            P01_S24		
            P01_S25		
            P01_S26		
            P01_S27		
            P01_S28		
            P01_S29		
            P01_S30		
            P01_S31		
            P01_S32		
            P01_S33		
            P01_S34		
            P01_S35		
            P01_S36		
            P01_S37		
            P01_S38		
            P01_S39		
            P01_S40		
            P01_S41		
            P01_S42		
            P01_S43		
            P01_S44		
            P01_S45		
            P01_S46		
            P01_S47		
            P01_S48		
            P01_S49		
            P02_S01		
            P02_S02		
            P02_S03		
            P02_S04		
            P02_S05		
            P02_S06		
            P02_S07		
            P02_S08		
            P02_S09		
            P02_S10		
            P02_S11		
            P02_S12		
            P02_S13		
            P02_S14		
            P02_S15		
            P02_S16		
            P02_S17		
            P02_S18		
            P02_S19		
            P02_S20		
            P02_S21		
            P02_S22		
            P02_S23		
            P02_S24		
            P02_S25		
            P02_S26		
            P02_S27		
            P02_S28		
            P02_S29		
            P02_S30		
            P02_S31		
            P02_S32		
            P02_S33		
            P02_S34		
            P02_S35		
            P02_S36		
            P02_S37		
            P02_S38		
            P02_S39		
            P02_S40		
            P02_S41		
            P02_S42		
            P02_S43		
            P02_S44		
            P02_S45		
            P02_S46		
            P02_S47		
            P02_S48		
            P02_S49		
            P03_S01		
            P03_S02		
            P03_S03		
            P03_S04		
            P03_S05		
            P03_S06		
            P03_S07		
            P03_S08		
            P03_S09		
            P03_S10		
            P03_S11		
            P03_S12		
            P03_S13		
            P03_S14		
            P03_S15		
            P03_S16		
            P03_S17		
            P03_S18		
            P03_S19		
            P03_S20		
            P03_S21		
            P03_S22		
            P03_S23		
            P03_S24		
            P03_S25		
            P03_S26		
            P03_S27		
            P03_S28		
            P03_S29		
            P03_S30		
            P03_S31		
            P03_S32		
            P03_S33		
            P03_S34		
            P03_S35		
            P03_S36		
            P03_S37		
            P03_S38		
            P03_S39		
            P03_S40		
            P03_S41		
            P03_S42		
            P03_S43		
            P03_S44		
            P03_S45		
            P03_S46		
            P03_S47		
            P03_S48		
            P03_S49		
            P04_S01		
            P04_S02		
            P04_S03		
            P04_S04		
            P04_S05		
            P04_S06		
            P04_S07		
            P04_S08		
            P04_S09		
            P04_S10		
            P04_S11		
            P04_S12		
            P04_S13		
            P04_S14		
            P04_S15		
            P04_S16		
            P04_S17		
            P04_S18		
            P04_S19		
            P04_S20		
            P04_S21		
            P04_S22		
            P04_S23		
            P04_S24		
            P04_S25		
            P04_S26		
            P04_S27		
            P04_S28		
            P04_S29		
            P04_S30		
            P04_S31		
            P04_S32		
            P04_S33		
            P04_S34		
            P04_S35		
            P04_S36		
            P04_S37		
            P04_S38		
            P04_S39		
            P04_S40		
            P04_S41		
            P04_S42		
            P04_S43		
            P04_S44		
            P04_S45		
            P04_S46		
            P04_S47		
            P04_S48		
            P04_S49		
            P05_S01		
            P05_S02		
            P05_S03		
            P05_S04		
            P05_S05		
            P05_S06		
            P05_S07		
            P05_S08		
            P05_S09		
            P05_S10		
            P05_S11		
            P05_S12		
            P05_S13		
            P05_S14		
            P05_S15		
            P05_S16		
            P05_S17		
            P05_S18		
            P05_S19		
            P05_S20		
            P05_S21		
            P05_S22		
            P05_S23		
            P05_S24		
            P05_S25		
            P05_S26		
            P05_S27		
            P05_S28		
            P05_S29		
            P05_S30		
            P05_S31		
            P05_S32		
            P05_S33		
            P05_S34		
            P05_S35		
            P05_S36		
            P05_S37		
            P05_S38		
            P05_S39		
            P05_S40		
            P05_S41		
            P05_S42		
            P05_S43		
            P05_S44		
            P05_S45		
            P05_S46		
            P05_S47		
            P05_S48		
            P05_S49		

        END Class

    END SubObjects

    BEGIN References
        Instance *
            *		
        END Instance
        Instance Facility/GS_01
            Facility/GS_01		
        END Instance
        Instance Satellite/P01_S01
            Satellite/P01_S01		
        END Instance
        Instance Satellite/P01_S02
            Satellite/P01_S02		
        END Instance
        Instance Satellite/P01_S03
            Satellite/P01_S03		
        END Instance
        Instance Satellite/P01_S04
            Satellite/P01_S04		
        END Instance
        Instance Satellite/P01_S05
            Satellite/P01_S05		
        END Instance
        Instance Satellite/P01_S06
            Satellite/P01_S06		
        END Instance
        Instance Satellite/P01_S07
            Satellite/P01_S07		
        END Instance
        Instance Satellite/P01_S08
            Satellite/P01_S08		
        END Instance
        Instance Satellite/P01_S09
            Satellite/P01_S09		
        END Instance
        Instance Satellite/P01_S10
            Satellite/P01_S10		
        END Instance
        Instance Satellite/P01_S11
            Satellite/P01_S11		
        END Instance
        Instance Satellite/P01_S12
            Satellite/P01_S12		
        END Instance
        Instance Satellite/P01_S13
            Satellite/P01_S13		
        END Instance
        Instance Satellite/P01_S14
            Satellite/P01_S14		
        END Instance
        Instance Satellite/P01_S15
            Satellite/P01_S15		
        END Instance
        Instance Satellite/P01_S16
            Satellite/P01_S16		
        END Instance
        Instance Satellite/P01_S17
            Satellite/P01_S17		
        END Instance
        Instance Satellite/P01_S18
            Satellite/P01_S18		
        END Instance
        Instance Satellite/P01_S19
            Satellite/P01_S19		
        END Instance
        Instance Satellite/P01_S20
            Satellite/P01_S20		
        END Instance
        Instance Satellite/P01_S21
            Satellite/P01_S21		
        END Instance
        Instance Satellite/P01_S22
            Satellite/P01_S22		
        END Instance
        Instance Satellite/P01_S23
            Satellite/P01_S23		
        END Instance
        Instance Satellite/P01_S24
            Satellite/P01_S24		
        END Instance
        Instance Satellite/P01_S25
            Satellite/P01_S25		
        END Instance
        Instance Satellite/P01_S26
            Satellite/P01_S26		
        END Instance
        Instance Satellite/P01_S27
            Satellite/P01_S27		
        END Instance
        Instance Satellite/P01_S28
            Satellite/P01_S28		
        END Instance
        Instance Satellite/P01_S29
            Satellite/P01_S29		
        END Instance
        Instance Satellite/P01_S30
            Satellite/P01_S30		
        END Instance
        Instance Satellite/P01_S31
            Satellite/P01_S31		
        END Instance
        Instance Satellite/P01_S32
            Satellite/P01_S32		
        END Instance
        Instance Satellite/P01_S33
            Satellite/P01_S33		
        END Instance
        Instance Satellite/P01_S34
            Satellite/P01_S34		
        END Instance
        Instance Satellite/P01_S35
            Satellite/P01_S35		
        END Instance
        Instance Satellite/P01_S36
            Satellite/P01_S36		
        END Instance
        Instance Satellite/P01_S37
            Satellite/P01_S37		
        END Instance
        Instance Satellite/P01_S38
            Satellite/P01_S38		
        END Instance
        Instance Satellite/P01_S39
            Satellite/P01_S39		
        END Instance
        Instance Satellite/P01_S40
            Satellite/P01_S40		
        END Instance
        Instance Satellite/P01_S41
            Satellite/P01_S41		
        END Instance
        Instance Satellite/P01_S42
            Satellite/P01_S42		
        END Instance
        Instance Satellite/P01_S43
            Satellite/P01_S43		
        END Instance
        Instance Satellite/P01_S44
            Satellite/P01_S44		
        END Instance
        Instance Satellite/P01_S45
            Satellite/P01_S45		
        END Instance
        Instance Satellite/P01_S46
            Satellite/P01_S46		
        END Instance
        Instance Satellite/P01_S47
            Satellite/P01_S47		
        END Instance
        Instance Satellite/P01_S48
            Satellite/P01_S48		
        END Instance
        Instance Satellite/P01_S49
            Satellite/P01_S49		
        END Instance
        Instance Satellite/P02_S01
            Satellite/P02_S01		
        END Instance
        Instance Satellite/P02_S02
            Satellite/P02_S02		
        END Instance
        Instance Satellite/P02_S03
            Satellite/P02_S03		
        END Instance
        Instance Satellite/P02_S04
            Satellite/P02_S04		
        END Instance
        Instance Satellite/P02_S05
            Satellite/P02_S05		
        END Instance
        Instance Satellite/P02_S06
            Satellite/P02_S06		
        END Instance
        Instance Satellite/P02_S07
            Satellite/P02_S07		
        END Instance
        Instance Satellite/P02_S08
            Satellite/P02_S08		
        END Instance
        Instance Satellite/P02_S09
            Satellite/P02_S09		
        END Instance
        Instance Satellite/P02_S10
            Satellite/P02_S10		
        END Instance
        Instance Satellite/P02_S11
            Satellite/P02_S11		
        END Instance
        Instance Satellite/P02_S12
            Satellite/P02_S12		
        END Instance
        Instance Satellite/P02_S13
            Satellite/P02_S13		
        END Instance
        Instance Satellite/P02_S14
            Satellite/P02_S14		
        END Instance
        Instance Satellite/P02_S15
            Satellite/P02_S15		
        END Instance
        Instance Satellite/P02_S16
            Satellite/P02_S16		
        END Instance
        Instance Satellite/P02_S17
            Satellite/P02_S17		
        END Instance
        Instance Satellite/P02_S18
            Satellite/P02_S18		
        END Instance
        Instance Satellite/P02_S19
            Satellite/P02_S19		
        END Instance
        Instance Satellite/P02_S20
            Satellite/P02_S20		
        END Instance
        Instance Satellite/P02_S21
            Satellite/P02_S21		
        END Instance
        Instance Satellite/P02_S22
            Satellite/P02_S22		
        END Instance
        Instance Satellite/P02_S23
            Satellite/P02_S23		
        END Instance
        Instance Satellite/P02_S24
            Satellite/P02_S24		
        END Instance
        Instance Satellite/P02_S25
            Satellite/P02_S25		
        END Instance
        Instance Satellite/P02_S26
            Satellite/P02_S26		
        END Instance
        Instance Satellite/P02_S27
            Satellite/P02_S27		
        END Instance
        Instance Satellite/P02_S28
            Satellite/P02_S28		
        END Instance
        Instance Satellite/P02_S29
            Satellite/P02_S29		
        END Instance
        Instance Satellite/P02_S30
            Satellite/P02_S30		
        END Instance
        Instance Satellite/P02_S31
            Satellite/P02_S31		
        END Instance
        Instance Satellite/P02_S32
            Satellite/P02_S32		
        END Instance
        Instance Satellite/P02_S33
            Satellite/P02_S33		
        END Instance
        Instance Satellite/P02_S34
            Satellite/P02_S34		
        END Instance
        Instance Satellite/P02_S35
            Satellite/P02_S35		
        END Instance
        Instance Satellite/P02_S36
            Satellite/P02_S36		
        END Instance
        Instance Satellite/P02_S37
            Satellite/P02_S37		
        END Instance
        Instance Satellite/P02_S38
            Satellite/P02_S38		
        END Instance
        Instance Satellite/P02_S39
            Satellite/P02_S39		
        END Instance
        Instance Satellite/P02_S40
            Satellite/P02_S40		
        END Instance
        Instance Satellite/P02_S41
            Satellite/P02_S41		
        END Instance
        Instance Satellite/P02_S42
            Satellite/P02_S42		
        END Instance
        Instance Satellite/P02_S43
            Satellite/P02_S43		
        END Instance
        Instance Satellite/P02_S44
            Satellite/P02_S44		
        END Instance
        Instance Satellite/P02_S45
            Satellite/P02_S45		
        END Instance
        Instance Satellite/P02_S46
            Satellite/P02_S46		
        END Instance
        Instance Satellite/P02_S47
            Satellite/P02_S47		
        END Instance
        Instance Satellite/P02_S48
            Satellite/P02_S48		
        END Instance
        Instance Satellite/P02_S49
            Satellite/P02_S49		
        END Instance
        Instance Satellite/P03_S01
            Satellite/P03_S01		
        END Instance
        Instance Satellite/P03_S02
            Satellite/P03_S02		
        END Instance
        Instance Satellite/P03_S03
            Satellite/P03_S03		
        END Instance
        Instance Satellite/P03_S04
            Satellite/P03_S04		
        END Instance
        Instance Satellite/P03_S05
            Satellite/P03_S05		
        END Instance
        Instance Satellite/P03_S06
            Satellite/P03_S06		
        END Instance
        Instance Satellite/P03_S07
            Satellite/P03_S07		
        END Instance
        Instance Satellite/P03_S08
            Satellite/P03_S08		
        END Instance
        Instance Satellite/P03_S09
            Satellite/P03_S09		
        END Instance
        Instance Satellite/P03_S10
            Satellite/P03_S10		
        END Instance
        Instance Satellite/P03_S11
            Satellite/P03_S11		
        END Instance
        Instance Satellite/P03_S12
            Satellite/P03_S12		
        END Instance
        Instance Satellite/P03_S13
            Satellite/P03_S13		
        END Instance
        Instance Satellite/P03_S14
            Satellite/P03_S14		
        END Instance
        Instance Satellite/P03_S15
            Satellite/P03_S15		
        END Instance
        Instance Satellite/P03_S16
            Satellite/P03_S16		
        END Instance
        Instance Satellite/P03_S17
            Satellite/P03_S17		
        END Instance
        Instance Satellite/P03_S18
            Satellite/P03_S18		
        END Instance
        Instance Satellite/P03_S19
            Satellite/P03_S19		
        END Instance
        Instance Satellite/P03_S20
            Satellite/P03_S20		
        END Instance
        Instance Satellite/P03_S21
            Satellite/P03_S21		
        END Instance
        Instance Satellite/P03_S22
            Satellite/P03_S22		
        END Instance
        Instance Satellite/P03_S23
            Satellite/P03_S23		
        END Instance
        Instance Satellite/P03_S24
            Satellite/P03_S24		
        END Instance
        Instance Satellite/P03_S25
            Satellite/P03_S25		
        END Instance
        Instance Satellite/P03_S26
            Satellite/P03_S26		
        END Instance
        Instance Satellite/P03_S27
            Satellite/P03_S27		
        END Instance
        Instance Satellite/P03_S28
            Satellite/P03_S28		
        END Instance
        Instance Satellite/P03_S29
            Satellite/P03_S29		
        END Instance
        Instance Satellite/P03_S30
            Satellite/P03_S30		
        END Instance
        Instance Satellite/P03_S31
            Satellite/P03_S31		
        END Instance
        Instance Satellite/P03_S32
            Satellite/P03_S32		
        END Instance
        Instance Satellite/P03_S33
            Satellite/P03_S33		
        END Instance
        Instance Satellite/P03_S34
            Satellite/P03_S34		
        END Instance
        Instance Satellite/P03_S35
            Satellite/P03_S35		
        END Instance
        Instance Satellite/P03_S36
            Satellite/P03_S36		
        END Instance
        Instance Satellite/P03_S37
            Satellite/P03_S37		
        END Instance
        Instance Satellite/P03_S38
            Satellite/P03_S38		
        END Instance
        Instance Satellite/P03_S39
            Satellite/P03_S39		
        END Instance
        Instance Satellite/P03_S40
            Satellite/P03_S40		
        END Instance
        Instance Satellite/P03_S41
            Satellite/P03_S41		
        END Instance
        Instance Satellite/P03_S42
            Satellite/P03_S42		
        END Instance
        Instance Satellite/P03_S43
            Satellite/P03_S43		
        END Instance
        Instance Satellite/P03_S44
            Satellite/P03_S44		
        END Instance
        Instance Satellite/P03_S45
            Satellite/P03_S45		
        END Instance
        Instance Satellite/P03_S46
            Satellite/P03_S46		
        END Instance
        Instance Satellite/P03_S47
            Satellite/P03_S47		
        END Instance
        Instance Satellite/P03_S48
            Satellite/P03_S48		
        END Instance
        Instance Satellite/P03_S49
            Satellite/P03_S49		
        END Instance
        Instance Satellite/P04_S01
            Satellite/P04_S01		
        END Instance
        Instance Satellite/P04_S02
            Satellite/P04_S02		
        END Instance
        Instance Satellite/P04_S03
            Satellite/P04_S03		
        END Instance
        Instance Satellite/P04_S04
            Satellite/P04_S04		
        END Instance
        Instance Satellite/P04_S05
            Satellite/P04_S05		
        END Instance
        Instance Satellite/P04_S06
            Satellite/P04_S06		
        END Instance
        Instance Satellite/P04_S07
            Satellite/P04_S07		
        END Instance
        Instance Satellite/P04_S08
            Satellite/P04_S08		
        END Instance
        Instance Satellite/P04_S09
            Satellite/P04_S09		
        END Instance
        Instance Satellite/P04_S10
            Satellite/P04_S10		
        END Instance
        Instance Satellite/P04_S11
            Satellite/P04_S11		
        END Instance
        Instance Satellite/P04_S12
            Satellite/P04_S12		
        END Instance
        Instance Satellite/P04_S13
            Satellite/P04_S13		
        END Instance
        Instance Satellite/P04_S14
            Satellite/P04_S14		
        END Instance
        Instance Satellite/P04_S15
            Satellite/P04_S15		
        END Instance
        Instance Satellite/P04_S16
            Satellite/P04_S16		
        END Instance
        Instance Satellite/P04_S17
            Satellite/P04_S17		
        END Instance
        Instance Satellite/P04_S18
            Satellite/P04_S18		
        END Instance
        Instance Satellite/P04_S19
            Satellite/P04_S19		
        END Instance
        Instance Satellite/P04_S20
            Satellite/P04_S20		
        END Instance
        Instance Satellite/P04_S21
            Satellite/P04_S21		
        END Instance
        Instance Satellite/P04_S22
            Satellite/P04_S22		
        END Instance
        Instance Satellite/P04_S23
            Satellite/P04_S23		
        END Instance
        Instance Satellite/P04_S24
            Satellite/P04_S24		
        END Instance
        Instance Satellite/P04_S25
            Satellite/P04_S25		
        END Instance
        Instance Satellite/P04_S26
            Satellite/P04_S26		
        END Instance
        Instance Satellite/P04_S27
            Satellite/P04_S27		
        END Instance
        Instance Satellite/P04_S28
            Satellite/P04_S28		
        END Instance
        Instance Satellite/P04_S29
            Satellite/P04_S29		
        END Instance
        Instance Satellite/P04_S30
            Satellite/P04_S30		
        END Instance
        Instance Satellite/P04_S31
            Satellite/P04_S31		
        END Instance
        Instance Satellite/P04_S32
            Satellite/P04_S32		
        END Instance
        Instance Satellite/P04_S33
            Satellite/P04_S33		
        END Instance
        Instance Satellite/P04_S34
            Satellite/P04_S34		
        END Instance
        Instance Satellite/P04_S35
            Satellite/P04_S35		
        END Instance
        Instance Satellite/P04_S36
            Satellite/P04_S36		
        END Instance
        Instance Satellite/P04_S37
            Satellite/P04_S37		
        END Instance
        Instance Satellite/P04_S38
            Satellite/P04_S38		
        END Instance
        Instance Satellite/P04_S39
            Satellite/P04_S39		
        END Instance
        Instance Satellite/P04_S40
            Satellite/P04_S40		
        END Instance
        Instance Satellite/P04_S41
            Satellite/P04_S41		
        END Instance
        Instance Satellite/P04_S42
            Satellite/P04_S42		
        END Instance
        Instance Satellite/P04_S43
            Satellite/P04_S43		
        END Instance
        Instance Satellite/P04_S44
            Satellite/P04_S44		
        END Instance
        Instance Satellite/P04_S45
            Satellite/P04_S45		
        END Instance
        Instance Satellite/P04_S46
            Satellite/P04_S46		
        END Instance
        Instance Satellite/P04_S47
            Satellite/P04_S47		
        END Instance
        Instance Satellite/P04_S48
            Satellite/P04_S48		
        END Instance
        Instance Satellite/P04_S49
            Satellite/P04_S49		
        END Instance
        Instance Satellite/P05_S01
            Satellite/P05_S01		
        END Instance
        Instance Satellite/P05_S02
            Satellite/P05_S02		
        END Instance
        Instance Satellite/P05_S03
            Satellite/P05_S03		
        END Instance
        Instance Satellite/P05_S04
            Satellite/P05_S04		
        END Instance
        Instance Satellite/P05_S05
            Satellite/P05_S05		
        END Instance
        Instance Satellite/P05_S06
            Satellite/P05_S06		
        END Instance
        Instance Satellite/P05_S07
            Satellite/P05_S07		
        END Instance
        Instance Satellite/P05_S08
            Satellite/P05_S08		
        END Instance
        Instance Satellite/P05_S09
            Satellite/P05_S09		
        END Instance
        Instance Satellite/P05_S10
            Satellite/P05_S10		
        END Instance
        Instance Satellite/P05_S11
            Satellite/P05_S11		
        END Instance
        Instance Satellite/P05_S12
            Satellite/P05_S12		
        END Instance
        Instance Satellite/P05_S13
            Satellite/P05_S13		
        END Instance
        Instance Satellite/P05_S14
            Satellite/P05_S14		
        END Instance
        Instance Satellite/P05_S15
            Satellite/P05_S15		
        END Instance
        Instance Satellite/P05_S16
            Satellite/P05_S16		
        END Instance
        Instance Satellite/P05_S17
            Satellite/P05_S17		
        END Instance
        Instance Satellite/P05_S18
            Satellite/P05_S18		
        END Instance
        Instance Satellite/P05_S19
            Satellite/P05_S19		
        END Instance
        Instance Satellite/P05_S20
            Satellite/P05_S20		
        END Instance
        Instance Satellite/P05_S21
            Satellite/P05_S21		
        END Instance
        Instance Satellite/P05_S22
            Satellite/P05_S22		
        END Instance
        Instance Satellite/P05_S23
            Satellite/P05_S23		
        END Instance
        Instance Satellite/P05_S24
            Satellite/P05_S24		
        END Instance
        Instance Satellite/P05_S25
            Satellite/P05_S25		
        END Instance
        Instance Satellite/P05_S26
            Satellite/P05_S26		
        END Instance
        Instance Satellite/P05_S27
            Satellite/P05_S27		
        END Instance
        Instance Satellite/P05_S28
            Satellite/P05_S28		
        END Instance
        Instance Satellite/P05_S29
            Satellite/P05_S29		
        END Instance
        Instance Satellite/P05_S30
            Satellite/P05_S30		
        END Instance
        Instance Satellite/P05_S31
            Satellite/P05_S31		
        END Instance
        Instance Satellite/P05_S32
            Satellite/P05_S32		
        END Instance
        Instance Satellite/P05_S33
            Satellite/P05_S33		
        END Instance
        Instance Satellite/P05_S34
            Satellite/P05_S34		
        END Instance
        Instance Satellite/P05_S35
            Satellite/P05_S35		
        END Instance
        Instance Satellite/P05_S36
            Satellite/P05_S36		
        END Instance
        Instance Satellite/P05_S37
            Satellite/P05_S37		
        END Instance
        Instance Satellite/P05_S38
            Satellite/P05_S38		
        END Instance
        Instance Satellite/P05_S39
            Satellite/P05_S39		
        END Instance
        Instance Satellite/P05_S40
            Satellite/P05_S40		
        END Instance
        Instance Satellite/P05_S41
            Satellite/P05_S41		
        END Instance
        Instance Satellite/P05_S42
            Satellite/P05_S42		
        END Instance
        Instance Satellite/P05_S43
            Satellite/P05_S43		
        END Instance
        Instance Satellite/P05_S44
            Satellite/P05_S44		
        END Instance
        Instance Satellite/P05_S45
            Satellite/P05_S45		
        END Instance
        Instance Satellite/P05_S46
            Satellite/P05_S46		
        END Instance
        Instance Satellite/P05_S47
            Satellite/P05_S47		
        END Instance
        Instance Satellite/P05_S48
            Satellite/P05_S48		
        END Instance
        Instance Satellite/P05_S49
            Satellite/P05_S49		
        END Instance
    END References

END Scenario
