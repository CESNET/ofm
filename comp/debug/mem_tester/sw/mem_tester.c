/*****************************************************
mem_tester.c: program for communication with mem-tester comp
Copyright (C) 2021 CESNET z. s. p. o.
Author(s): Lukas Nevrkla <xnevrk03@stud.fit.vutbr.cz>

SPDX-License-Identifier: BSD-3-Clause
*****************************************************/

#include "common.h"
#include "core.h"
#include <getopt.h>

#define COMPATIBILE     "netcope,mem_tester"
#define REGS_TO_PRINT   64

enum LongArgIDs
{
    AUTO_PRECHARGE = 1,
    REFRESH_PERIOD_TICKS,
    XML,
    HIST,
};

const char *ShortOptions = "d:c:i:a:m:n:t:s:k:rwbpfhvgou";
struct option LongOptions[] = {
    {"help",            no_argument,        NULL,  'h' },
    {"auto-precharge",  no_argument,        NULL,  AUTO_PRECHARGE },
    {"refresh-period",  required_argument,  NULL,  REFRESH_PERIOD_TICKS },
    {"xml",             no_argument,        NULL,  XML },
    {"print-hist",      no_argument,        NULL,  HIST },
    {0,                 0,                  NULL,  0 }
};


/*!
 * \brief Display usage of program
 */
void usage(const char *me)
{
    printf("Usage: %s [-h] [-d path]\n", me);
    printf("-d path         Path to device [default: %s]\n", NFB_PATH_DEV(0));
    printf("-c comp         Compatibile of the mem_tester componet [default: %s]\n", COMPATIBILE);
    printf("-i index        Index of the mem_tester componet (when more instances are used)\n"
           "                When |index = g| it will return number of compatibile components\n");
    printf("-p              Print registers\n");
    printf("-g              Print device config (can be used with -v)\n");
    printf("-u              Print device status (can be used with -v)\n");
    printf("--print-hist    Prints latency histogram from last measurement\n");

    printf("Test related\n");
    //printf("-t type         Run test (type = %s/%s/%s/%s/%s)\n", TEST_ALL, TEST_SEQ, TEST_RAND, TEST_LAT_SEQ, TEST_LAT_RAND);
    printf("-t type         Run test (type = %s/%s/%s)\n", TEST_ALL, TEST_SEQ, TEST_RAND);
    printf("-b              Boot again - reset\n");
    printf("-n burst        Set burst count during test\n");
    printf("-k scale        Set address limit during test (1.0 = max.)\n");
    printf("-o              Only one simulateous read\n");
    printf("-v              Print only CSV\n");
    printf("--auto-precharge\n");
    printf("--refresh-period ticks\n");

    printf("AMM_GEN\n");
    printf("-m burst data   Content of a currently selected AMM word (512b hexa) inside manual r/w buffer\n");
    printf("-a addr         Manual addr\n");
    printf("-s burst        Manual set burst cnt\n");
    printf("-r              Manual read\n");
    printf("-w              Manual write\n");

    printf("AMM_PROBE\n");
    printf("-f              Measure latency to first word [default: to last]\n");

    printf("Others\n");
    printf("-h              Show this text\n");
    printf("--xml           Print in XML format\n");
}


/*!
 * \brief Program main function.
 *
 * \param argc       number of arguments
 * \param *argv[]    array with arguments
 *
 * \return     0 OK<BR>
 *             -1 error
 */
int main(int argc, char *argv[])
{
    bool printHelp          = false;
    bool runTest            = false;
    bool reset              = false;
    bool manualSetAddr      = false;
    bool manualRead         = false;
    bool manualWrite        = false;
    bool manualWriteToBuff  = false;
    bool printRegs          = false;
    bool printConfig        = false;
    bool printStatus        = false;
    bool printCompCnt       = false;
    bool setRefresh         = false;
    bool printHist          = false;

    long manualAddr         = 0;
    char *manualData;
    long manualBurst        = 0;
    long manualBurstCnt     = -1;
    int res_code            = 0;
    char *file              = NFB_PATH_DEV(0);
    char *compatibile       = COMPATIBILE;
    long index              = 0;
    long refreshPeriod      = 0;

    struct TestParams_s testParams = 
    {
        .latencyToFirst     = false,
        .autoPrecharge      = false,
        .burstCnt           = DEFAULT_BURST_CNT,
        .onlyCSV            = false,
        .onlyXML            = false,
        .onlyOneSimultRead  = false,
        .addrLimScale        = 1.0,
    };

    srand(time(NULL));

    //////////////////////
    // Parse parameters //
    //////////////////////

    int c;
    int optionIndex;    // Index of found long option

    //while ((c = getopt(argc, argv, ARGUMENTS)) != -1) 
    while ((c = getopt_long(argc, argv, ShortOptions, LongOptions, &optionIndex)) != -1) 
    {
        switch (c) 
        {
            case 'd':
                file = optarg;
                break;
            case 'c':
                compatibile = optarg;
                break;
            case 'i':
                if (optarg[0] == 'g')
                    printCompCnt = true;
                else
                    index = strtoul(optarg, NULL, 10);
                break;
            case 't':
                runTest = true;
                testParams.typeStr = optarg;
                break;
            case 'a':
                manualAddr = strtoul(optarg, NULL, 10);
                manualSetAddr = true;
                break;
            case 's':
                manualBurstCnt = strtoul(optarg, NULL, 10);
                break;
            case 'n':
                testParams.burstCnt = strtoul(optarg, NULL, 10);
                break;
            case 'k':
                testParams.addrLimScale = strtold(optarg, NULL);
                break;
            case 'o':
                testParams.onlyOneSimultRead = true;
                break;
            case 'v':
                testParams.onlyCSV = true;
                break;
            case 'm':
                manualWriteToBuff = true;
                manualBurst = strtoul(optarg, NULL, 10);
                if (optind >= argc)
                { 
                    fprintf(stderr, "One missing argument for command -m\n");
                    return 1;
                }

                manualData = argv[optind];
                optind++;
                break;
            case 'r':
                manualRead = true;
                break;
            case 'w':
                manualWrite = true;
                break;
            case 'b':
                reset = true;
                break;
            case 'p':
                printRegs = true;
                break;
            case 'g':
                printConfig = true;
                break;
            case 'u':
                printStatus = true;
                break;
            case 'f':
                testParams.latencyToFirst = true;
                break;
            case 'h':
                printHelp = true;
                break;
            case AUTO_PRECHARGE:
                testParams.autoPrecharge = true;
                break;
            case REFRESH_PERIOD_TICKS:
                refreshPeriod = strtoul(optarg, NULL, 10);
                setRefresh = true;
                break;
            case XML:
                testParams.onlyXML = true;
                break;
            case HIST:
                printHist = true;
                break;
            default:
                printf("Unknown argument: %c\n", c);
        }
    }

    if (printHelp) 
    {
        usage(argv[0]);
        return EXIT_SUCCESS;
    }

    argc -= optind;
    argv += optind;

    // Connect to component
    res_code = Init(file, compatibile, index, printCompCnt);
    if (res_code != 0)
    {
        Finish();
        return res_code;
    }

    ///////////////
    // Main part //
    ///////////////

    if (reset)
    {
        printf("Reseting ... \n");
        Reset(true);        // EMIF
        Reset(false);       // mem-tester
    }

    if (setRefresh)
        SetRefreshPeriod(refreshPeriod);

    if (runTest)
    {
        bool testTypeMatch = false;

        if (strcmp(testParams.typeStr, TEST_SEQ) == 0 || strcmp(testParams.typeStr, TEST_ALL) == 0)
        {
            testTypeMatch   = true;
            testParams.type = SEQUENTIAL;

            if ( ! testParams.onlyCSV && ! testParams.onlyXML)
                printf("Running sequential test ...\n");
            RunTest(&testParams);
        }
        if (strcmp(testParams.typeStr, TEST_RAND) == 0 || strcmp(testParams.typeStr, TEST_ALL) == 0)
        {
            testTypeMatch   = true;
            testParams.type = RANDOM;

            if ( ! testParams.onlyCSV && ! testParams.onlyXML)
                printf("Running random indexing test ...\n");
            RunTest(&testParams);
        }
        
        if ( ! testTypeMatch)
            fprintf(stderr, "%s is invalid test type\n", testParams.typeStr);
    }

    if (manualBurstCnt > 0)
    {
        AMMGenSetBurst(manualBurstCnt);
    }

    if (manualSetAddr)
    {
        printf("Setting manual addr ... \n");
        AMMGenSetAddr(manualAddr);
    }

    if (manualRead)
    {
        printf("Manual read ... \n");
        ReadManualBuff();
        // Todo wait for vld
        PrintManualBuff();
    }

    if (manualWrite)
    {
        printf("Manual write ... \n");
        WriteManualBuff();
    }

    if (manualWriteToBuff)
    {
        printf("Editing manual buffer\n");
        FillManualBuff(manualBurst, manualData);
    }

    if (printRegs)
    {
        PrintRegs();

        /*
        //Raw register data
        printf("First %d registers:\n", REGS_TO_PRINT);
        for (unsigned i = 0; i < REGS_TO_PRINT; i++)
        {
            data = nfb_comp_read32(comp, 4 * i);
            printf("0x%08X = 0x%08X\n", i * 4, data);
        }
        */
    }

    if (printConfig)
    {
        struct DevConfig config;
        GetDevConfig(&config);

        if (testParams.onlyCSV)
            PrintDevConfigCSV(&config);
        else if (testParams.onlyXML)
            PrintDevConfigXML(&config);
        else
            PrintDevConfig(&config);
    }

    if (printStatus)
    {
        if (testParams.onlyCSV)
            PrintDevStatusCSV();
        else if (testParams.onlyXML)
            PrintDevStatusXML();
        else
            PrintDevStatus();
    }

    if (printHist)
        PrintHist();

    Finish();
    return res_code;
}
