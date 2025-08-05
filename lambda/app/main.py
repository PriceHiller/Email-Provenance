import app.handler

from aws_lambda_powertools import Logger
from aws_lambda_powertools.logging.buffer import LoggerBufferConfig




from fastapi import FastAPI
from mangum import Mangum

log = Logger(buffer_config=LoggerBufferConfig())

api = FastAPI()

handler = Mangum(api)

@api.post("/")
async def root(domain: str):
    return await app.handler.handler(domain)


if __name__ == "__main__":
    res = root({"domain": "pricehiller.com"})  # pyright: ignore[reportArgumentType]
    print(res)
