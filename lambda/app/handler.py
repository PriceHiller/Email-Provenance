from aws_lambda_powertools.utilities.typing import LambdaContext
from app.scrape import DkimRecord, scrape_dkim_selectors

from aws_lambda_powertools import Logger
from aws_lambda_powertools.logging.buffer import LoggerBufferConfig

log = Logger(service="ekim", buffer_config=LoggerBufferConfig())


async def handler(domain: str, _ctx: LambdaContext):
    try:
        log.info(f"Scraping dkim keys for domain: '{domain}'", domain=domain)
        scraped_keys = await scrape_dkim_selectors(domain)
        print(scraped_keys)
        records: list[DkimRecord] = [key.to_dkim_record() for key in scraped_keys]
        log.info(
            f"Finished scraping dkim keys for domain: '{domain}', scraped '{len(records)}' selectors",
            domain=domain,
            records=records,
        )
        return {
            "statusCode": 200,
            "status": "success",
            "message": f"successfully scraped {len(records)} dkim records",
            "records": records,
        }
    except Exception as e:
        log.error(e)
        return {
            "statusCode": 500,
            "status": "failed",
            "message": "failed to process request",
            "error": str(e),
        }
